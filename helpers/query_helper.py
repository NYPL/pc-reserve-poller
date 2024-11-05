import os

_ENVISIONWARE_QUERY = """
    SELECT
        pcrKey, pcrUserID, pcrMinutesUsed, pcrDateTime, pcrBranch, pcrArea, pcrUserData1
    FROM strad_bci
    WHERE pcrDateTime > '{date_time}'
        OR (pcrDateTime = '{date_time}' AND pcrKey > {key})
    ORDER BY pcrDateTime, pcrKey
    LIMIT {limit};"""

_SIERRA_QUERY = """
    WITH phrase_barcodes AS (
        SELECT record_id, index_entry
        FROM sierra_view.phrase_entry
        WHERE index_tag = 'b' AND record_id IN (
            SELECT record_id
            FROM sierra_view.phrase_entry
            WHERE index_tag || index_entry IN ({})
        )
    )
    SELECT
        barcode, id, ptype_code, pcode3,
        CASE WHEN LENGTH(TRIM(home_library_code)) = 0
            OR TRIM(home_library_code) = 'none' THEN NULL
            ELSE TRIM(home_library_code) END
    FROM phrase_barcodes INNER JOIN sierra_view.patron_view
        ON phrase_barcodes.record_id = patron_view.id
        AND phrase_barcodes.index_entry = patron_view.barcode;"""

_REDSHIFT_QUERY = """
    SELECT patron_id, postal_code, geoid
    FROM {table}
    WHERE patron_id IN ({ids});"""


def build_envisionware_query(date_time, key):
    return _ENVISIONWARE_QUERY.format(
        date_time=date_time, key=key, limit=os.environ["ENVISIONWARE_BATCH_SIZE"]
    )


def build_sierra_query(barcodes):
    return _SIERRA_QUERY.format(barcodes)


def build_redshift_query(table, ids):
    return _REDSHIFT_QUERY.format(table=table, ids=ids)
