import json
import os
import pandas as pd

from concurrent.futures import ThreadPoolExecutor
from helpers.query_helper import (
    build_envisionware_query,
    build_redshift_query,
    build_sierra_query,
)
from nypl_py_utils.classes.avro_client import AvroEncoder
from nypl_py_utils.classes.kinesis_client import KinesisClient
from nypl_py_utils.classes.mysql_client import MySQLClient
from nypl_py_utils.classes.postgresql_client import PostgreSQLClient
from nypl_py_utils.classes.redshift_client import RedshiftClient
from nypl_py_utils.classes.s3_client import S3Client
from nypl_py_utils.functions.config_helper import load_env_file
from nypl_py_utils.functions.log_helper import create_log
from nypl_py_utils.functions.obfuscation_helper import obfuscate


_DTYPE_MAP = {
    "patron_id": "string",
    "patron_retrieval_status": "string",
    "ptype_code": "Int64",
    "patron_home_library_code": "string",
    "pcode3": "Int64",
    "postal_code": "string",
    "geoid": "string",
    "key": "string",
    "minutes_used": "Int64",
    "transaction_et": "string",
    "branch": "string",
    "area": "string",
    "staff_override": "string",
}


def main():
    load_env_file(os.environ["ENVIRONMENT"], "config/{}.yaml")
    logger = create_log(__name__)

    s3_client = S3Client(os.environ["S3_BUCKET"], os.environ["S3_RESOURCE"])
    avro_encoder = AvroEncoder(os.environ["PC_RESERVE_SCHEMA_URL"])
    kinesis_client = KinesisClient(
        os.environ["KINESIS_STREAM_ARN"], int(os.environ["KINESIS_BATCH_SIZE"])
    )

    envisionware_client = MySQLClient(
        os.environ["ENVISIONWARE_DB_HOST"],
        os.environ["ENVISIONWARE_DB_PORT"],
        os.environ["ENVISIONWARE_DB_NAME"],
        os.environ["ENVISIONWARE_DB_USER"],
        os.environ["ENVISIONWARE_DB_PASSWORD"],
    )
    sierra_client = PostgreSQLClient(
        os.environ["SIERRA_DB_HOST"],
        os.environ["SIERRA_DB_PORT"],
        os.environ["SIERRA_DB_NAME"],
        os.environ["SIERRA_DB_USER"],
        os.environ["SIERRA_DB_PASSWORD"],
    )
    redshift_client = RedshiftClient(
        os.environ["REDSHIFT_DB_HOST"],
        os.environ["REDSHIFT_DB_NAME"],
        os.environ["REDSHIFT_DB_USER"],
        os.environ["REDSHIFT_DB_PASSWORD"],
    )

    has_max_batches = "MAX_BATCHES" in os.environ
    finished = False
    batch_number = 1
    poller_state = None
    while not finished:
        # Retrieve the query parameters to use for this batch
        poller_state = _get_poller_state(s3_client, poller_state, batch_number)
        logger.info(f"Begin processing batch {batch_number} with state {poller_state}")

        # Get data from Envisionware
        envisionware_client.connect()
        pc_reserve_raw_data = envisionware_client.execute_query(
            build_envisionware_query(
                poller_state["pcr_date_time"], poller_state["pcr_key"]
            )
        )
        envisionware_client.close_connection()
        if not pc_reserve_raw_data:
            break
        pc_reserve_df = pd.DataFrame(
            data=pc_reserve_raw_data,
            columns=[
                "key",
                "barcode",
                "minutes_used",
                "transaction_et",
                "branch",
                "area",
                "staff_override",
            ],
        )
        pc_reserve_df["key"] = pc_reserve_df["key"].astype("Int64")
        pc_reserve_df[["key", "barcode"]] = pc_reserve_df[["key", "barcode"]].astype(
            "string"
        )
        pc_reserve_df["transaction_et"] = pc_reserve_df["transaction_et"].dt.date

        # Obfuscate key
        logger.info("Obfuscating pcr keys")
        with ThreadPoolExecutor() as executor:
            pc_reserve_df["key"] = list(executor.map(obfuscate, pc_reserve_df["key"]))

        # Query Sierra for patron info using the patron barcodes
        barcodes_str = "'b" + "','b".join(pc_reserve_df["barcode"].unique()) + "'"
        sierra_client.connect()
        sierra_raw_data = sierra_client.execute_query(build_sierra_query(barcodes_str))
        sierra_client.close_connection()
        sierra_df = pd.DataFrame(
            data=sierra_raw_data,
            columns=[
                "barcode",
                "patron_id",
                "ptype_code",
                "pcode3",
                "patron_home_library_code",
            ],
        )

        # Some barcodes correspond to multiple patron records. For these barcodes, do
        # not use patron information from any of the records.
        sierra_df = sierra_df[pd.notnull(sierra_df["barcode"])]
        sierra_df = sierra_df.drop_duplicates("barcode", keep=False)
        sierra_df["patron_id"] = sierra_df["patron_id"].astype("Int64").astype("string")

        # Merge the dataframes, set the patron retrieval status, and obfuscate the
        # patron_id. The patron_id is either the Sierra id or, if no Sierra id is found
        # for the barcode, the barcode prepended with 'barcode '.
        pc_reserve_df = pc_reserve_df.merge(sierra_df, how="left", on="barcode")
        pc_reserve_df = pc_reserve_df.apply(_set_patron_retrieval_status, axis=1)
        with ThreadPoolExecutor() as executor:
            pc_reserve_df["patron_id"] = list(
                executor.map(obfuscate, pc_reserve_df["patron_id"])
            )

        # Query Redshift for the zip code and geoid using the obfuscated Sierra ids
        sierra_ids = pc_reserve_df.loc[
            pc_reserve_df["patron_retrieval_status"] == "found", "patron_id"
        ]
        if not sierra_ids.empty:
            ids_str = "'" + "','".join(sierra_ids.unique()) + "'"
            redshift_table = "patron_info"
            if os.environ["REDSHIFT_DB_NAME"] != "production":
                redshift_table += "_" + os.environ["REDSHIFT_DB_NAME"]
            redshift_client.connect()
            redshift_raw_data = redshift_client.execute_query(
                build_redshift_query(redshift_table, ids_str)
            )
            redshift_client.close_connection()
        else:
            logger.info("No Sierra ids found to query Redshift with")
            redshift_raw_data = []
        redshift_df = pd.DataFrame(
            data=redshift_raw_data, columns=["patron_id", "postal_code", "geoid"]
        )

        # Merge the dataframes and convert necessary fields to integers
        pc_reserve_df = pc_reserve_df.merge(redshift_df, how="left", on="patron_id")
        pc_reserve_df = pc_reserve_df.astype(_DTYPE_MAP)

        # Encode the resulting data and send it to Kinesis
        results_df = pc_reserve_df[
            [
                "patron_id",
                "ptype_code",
                "patron_home_library_code",
                "pcode3",
                "postal_code",
                "geoid",
                "key",
                "minutes_used",
                "transaction_et",
                "branch",
                "area",
                "staff_override",
                "patron_retrieval_status",
            ]
        ]
        encoded_records = avro_encoder.encode_batch(
            json.loads(results_df.to_json(orient="records"))
        )
        if os.environ.get("IGNORE_KINESIS", False) != "True":
            kinesis_client.send_records(encoded_records)

        # Update the poller state and set it in S3
        poller_state["pcr_key"] = str(pc_reserve_raw_data[-1][0])
        poller_state["pcr_date_time"] = str(pc_reserve_raw_data[-1][3])
        if os.environ.get("IGNORE_CACHE", False) != "True":
            s3_client.set_cache(poller_state)

        # Check if processing is complete
        reached_max_batches = has_max_batches and batch_number >= int(
            os.environ["MAX_BATCHES"]
        )
        no_more_records = len(pc_reserve_raw_data) < int(
            os.environ["ENVISIONWARE_BATCH_SIZE"]
        )
        finished = reached_max_batches or no_more_records
        batch_number += 1

    logger.info(
        f"Finished processing {batch_number - 1} batches; closing AWS connections"
    )
    s3_client.close()
    kinesis_client.close()


def _set_patron_retrieval_status(row):
    """Sets a barcode's Sierra retrieval status"""
    if pd.notnull(row["patron_id"]):
        row["patron_retrieval_status"] = "found"
    elif row["barcode"].startswith("25555"):
        row["patron_retrieval_status"] = "guest_pass"
        row["patron_id"] = "barcode {}".format(row["barcode"])
    else:
        row["patron_retrieval_status"] = "missing"
        row["patron_id"] = "barcode {}".format(row["barcode"])
    return row


def _get_poller_state(s3_client, poller_state, batch_number):
    """Retrieves the poller state from the S3 cache, the config, or the local memory"""
    if os.environ.get("IGNORE_CACHE", False) != "True":
        return s3_client.fetch_cache()
    elif batch_number == 1:
        return {
            "pcr_key": os.environ.get("PCR_KEY", 0),
            "pcr_date_time": os.environ.get(
                "PCR_DATE_TIME", "2023-01-01 00:00:00 +0000"
            ),
        }
    else:
        return poller_state


if __name__ == "__main__":
    main()
