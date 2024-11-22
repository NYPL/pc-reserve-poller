import main
import os
import pandas as pd
import pytest

from datetime import datetime
from pandas.testing import assert_series_equal

_ENVISIONWARE_DATA = [
    (10000000, "barcode1", 100, datetime(2023, 1, 1, 1, 0, 0), "branch1", "area1",
     "staff_override1"),
    (20000000, "25555000000000", 200, datetime(2023, 2, 2, 2, 0, 0), "branch2", "area2",
     "staff_override2"),
    (30000000, "barcode3", 300, datetime(2023, 3, 3, 3, 0, 0), "branch3", "area3",
     "staff_override3"),
    (40000000, "barcode4", 400, datetime(2023, 4, 4, 4, 0, 0), "branch4", "area4",
     "staff_override4"),
]

_SIERRA_DF = pd.DataFrame([
    ("111111111111", "barcode1", 1, 10, "lib1"),
    ("444444444444", "barcode4", 4, 40, "lib4")],
    columns=["patron_id", "barcode", "ptype_code", "pcode3",
             "patron_home_library_code"])
_SIERRA_DF["patron_id"] = _SIERRA_DF["patron_id"].astype("string")

_REDSHIFT_DF = pd.DataFrame(
    [["obf_id1", "zip1", "geoid1"],],
    columns=["patron_id", "postal_code", "geoid"]
)

_RESULTS = [
    {"patron_id": "obf_id1", "ptype_code": 1, "patron_home_library_code": "lib1",
     "pcode3": 10, "postal_code": "zip1", "geoid": "geoid1", "key": "obf_key1",
     "minutes_used": 100, "transaction_et": "2023-01-01", "branch": "branch1",
     "area": "area1", "staff_override": "staff_override1",
     "patron_retrieval_status": "found"},
    {"patron_id": "obf_id2", "ptype_code": None, "patron_home_library_code": None,
     "pcode3": None, "postal_code": None, "geoid": None, "key": "obf_key2",
     "minutes_used": 200, "transaction_et": "2023-02-02", "branch": "branch2",
     "area": "area2", "staff_override": "staff_override2",
     "patron_retrieval_status": "guest_pass"},
    {"patron_id": "obf_id3", "ptype_code": None, "patron_home_library_code": None,
     "pcode3": None, "postal_code": None, "geoid": None, "key": "obf_key3",
     "minutes_used": 300, "transaction_et": "2023-03-03", "branch": "branch3",
     "area": "area3", "staff_override": "staff_override3",
     "patron_retrieval_status": "missing"},
    {"patron_id": "obf_id4", "ptype_code": 4, "patron_home_library_code": "lib4",
     "pcode3": 40, "postal_code": None, "geoid": None, "key": "obf_key4",
     "minutes_used": 400, "transaction_et": "2023-04-04", "branch": "branch4",
     "area": "area4", "staff_override": "staff_override4",
     "patron_retrieval_status": "found"},
]

_ENCODED_RECORDS = [b"encoded1", b"encoded2", b"encoded3", b"encoded4"]


class TestMain:

    @pytest.fixture
    def mock_helpers(self, mocker):
        mocker.patch("main.load_env_file")
        mocker.patch("main.create_log")

    def _set_up_mock(self, package, mocker):
        mock = mocker.MagicMock()
        mocker.patch(package, return_value=mock)
        return mock

    def test_main_one_iteration(self, mock_helpers, mocker):
        mock_obfuscate = mocker.patch("main.obfuscate", side_effect=[
            "obf_key1", "obf_key2", "obf_key3", "obf_key4",
            "obf_id1", "obf_id2", "obf_id3", "obf_id4"])
        mock_get_sierra_patron_data_from_barcodes = mocker.patch(
            "main.get_sierra_patron_data_from_barcodes", return_value=_SIERRA_DF)
        mock_get_redshift_patron_data = mocker.patch(
            "main.get_redshift_patron_data", return_value=_REDSHIFT_DF)

        mock_kinesis_client = self._set_up_mock("main.KinesisClient", mocker)

        mock_avro_encoder = self._set_up_mock("main.AvroEncoder", mocker)
        mock_avro_encoder.encode_batch.return_value = _ENCODED_RECORDS

        mock_s3_client = self._set_up_mock("main.S3Client", mocker)
        mock_s3_client.fetch_cache.return_value = {
            "pcr_key": "test_key",
            "pcr_date_time": "test_dt",
        }

        mock_envisionware_query = mocker.patch(
            "main.build_envisionware_query", return_value="ENVISIONWARE QUERY"
        )
        mock_envisionware_client = self._set_up_mock("main.MySQLClient", mocker)
        mock_envisionware_client.execute_query.return_value = _ENVISIONWARE_DATA
        mock_sierra_client = self._set_up_mock("main.PostgreSQLClient", mocker)
        mock_redshift_client = self._set_up_mock("main.RedshiftClient", mocker)

        main.main()

        mock_s3_client.fetch_cache.assert_called_once()

        mock_envisionware_client.connect.assert_called_once()
        mock_envisionware_query.assert_called_once_with("test_dt", "test_key")
        mock_envisionware_client.execute_query.assert_called_once_with(
            "ENVISIONWARE QUERY"
        )
        mock_envisionware_client.close_connection.assert_called_once()

        mock_get_sierra_patron_data_from_barcodes.assert_called_once()
        sierra_args = mock_get_sierra_patron_data_from_barcodes.call_args[0]
        assert sierra_args[0] == mock_sierra_client
        assert_series_equal(
            sierra_args[1],
            pd.Series(["barcode1", "25555000000000", "barcode3", "barcode4"],
                      name="barcode", dtype="string"))

        mock_get_redshift_patron_data.assert_called_once()
        redshift_args = mock_get_redshift_patron_data.call_args[0]
        assert redshift_args[0] == mock_redshift_client
        assert_series_equal(
            redshift_args[1],
            pd.Series(["obf_id1", "obf_id4"], name="patron_id", index=[0, 3]))

        mock_obfuscate.assert_has_calls(
            [
                mocker.call("10000000"),
                mocker.call("20000000"),
                mocker.call("30000000"),
                mocker.call("40000000"),
                mocker.call("111111111111"),
                mocker.call("barcode 25555000000000"),
                mocker.call("barcode barcode3"),
                mocker.call("444444444444"),
            ]
        )
        mock_avro_encoder.encode_batch.assert_called_once_with(_RESULTS)
        mock_kinesis_client.send_records.assert_called_once_with(_ENCODED_RECORDS)

        mock_s3_client.set_cache.assert_called_once_with(
            {"pcr_key": "40000000", "pcr_date_time": "2023-04-04 04:00:00"}
        )
        mock_s3_client.close.assert_called_once()
        mock_kinesis_client.close.assert_called_once()

    def test_main_multiple_iterations(self, mock_helpers, mocker):
        del os.environ["MAX_BATCHES"]
        _TEST_ENVISIONWARE_DATA = [
            (i, "barcode{}".format(i), i, datetime(2023, i, i, i, 0, 0),
             "branch{}".format(i), "area{}".format(i),
             "staff_override{}".format(i))
            for i in range(1, 7)]
        mocker.patch("main.obfuscate")
        mocker.patch("main.AvroEncoder")
        mocker.patch("main.KinesisClient")
        mocker.patch("main.PostgreSQLClient")
        mocker.patch("main.RedshiftClient")

        mock_s3_client = self._set_up_mock("main.S3Client", mocker)
        mock_s3_client.fetch_cache.side_effect = [
            {"pcr_key": "test_key", "pcr_date_time": "test_dt"},
            {"pcr_key": "4", "pcr_date_time": "2023-04-04 04:00:00"},
        ]

        mock_envisionware_query = mocker.patch("main.build_envisionware_query")
        mock_envisionware_client = self._set_up_mock("main.MySQLClient", mocker)
        mock_envisionware_client.execute_query.side_effect = [
            _TEST_ENVISIONWARE_DATA[:4],
            _TEST_ENVISIONWARE_DATA[4:],
        ]

        main.main()

        assert mock_s3_client.fetch_cache.call_count == 2
        mock_s3_client.set_cache.assert_has_calls(
            [
                mocker.call({"pcr_key": "4", "pcr_date_time": "2023-04-04 04:00:00"}),
                mocker.call({"pcr_key": "6", "pcr_date_time": "2023-06-06 06:00:00"}),
            ]
        )
        mock_s3_client.close.assert_called_once()

        mock_envisionware_query.assert_has_calls(
            [
                mocker.call("test_dt", "test_key"),
                mocker.call("2023-04-04 04:00:00", "4"),
            ]
        )

    def test_main_no_envisionware_results(self, mock_helpers, mocker):
        del os.environ["MAX_BATCHES"]
        mocker.patch("main.obfuscate")
        mocker.patch("main.build_envisionware_query")
        mocker.patch("main.PostgreSQLClient")
        mocker.patch("main.RedshiftClient")
        mock_get_sierra_patron_data_from_barcodes = mocker.patch(
            "main.get_sierra_patron_data_from_barcodes")
        mock_get_redshift_patron_data = mocker.patch("main.get_redshift_patron_data")

        mock_s3_client = self._set_up_mock("main.S3Client", mocker)
        mock_kinesis_client = self._set_up_mock("main.KinesisClient", mocker)
        mock_avro_encoder = self._set_up_mock("main.AvroEncoder", mocker)

        mock_envisionware_client = self._set_up_mock("main.MySQLClient", mocker)
        mock_envisionware_client.execute_query.return_value = []

        main.main()

        mock_envisionware_client.close_connection.assert_called_once()
        mock_s3_client.fetch_cache.assert_called_once()
        mock_s3_client.close.assert_called_once()
        mock_kinesis_client.close.assert_called_once()

        mock_get_sierra_patron_data_from_barcodes.assert_not_called()
        mock_get_redshift_patron_data.assert_not_called()
        mock_avro_encoder.encode_batch.assert_not_called()
        mock_kinesis_client.send_records.assert_not_called()
        mock_s3_client.set_cache.assert_not_called()

    def test_main_no_sierra_redshift_results(self, mock_helpers, mocker):
        _TEST_ENVISIONWARE_DATA = [
            (i, "barcode{}".format(i), i, datetime(2023, i, i, i, 0, 0),
             "branch{}".format(i), "area{}".format(i),
             "staff_override{}".format(i))
            for i in range(1, 5)]
        _RESULTS = [
            {"patron_id": "obfuscated", "ptype_code": None,
             "patron_home_library_code": None, "pcode3": None,
             "postal_code": None, "geoid": None, "key": "obfuscated",
             "minutes_used": i, "transaction_et": "2023-0{}-0{}".format(i, i),
             "branch": "branch{}".format(i), "area": "area{}".format(i),
             "staff_override": "staff_override{}".format(i),
             "patron_retrieval_status": "missing"}
            for i in range(1, 5)]

        mocker.patch("main.build_envisionware_query")
        mocker.patch("main.KinesisClient")
        mocker.patch("main.S3Client")

        mock_obfuscate = mocker.patch("main.obfuscate", return_value="obfuscated")
        mocker.patch(
            "main.get_sierra_patron_data_from_barcodes",
            return_value=pd.DataFrame(
                [], columns=["patron_id", "barcode", "ptype_code", "pcode3",
                             "patron_home_library_code"]))
        mocker.patch(
            "main.get_redshift_patron_data",
            return_value=pd.DataFrame(
                [], columns=["patron_id", "postal_code", "geoid"]))
        mock_avro_encoder = self._set_up_mock("main.AvroEncoder", mocker)

        mock_envisionware_client = self._set_up_mock("main.MySQLClient", mocker)
        mock_envisionware_client.execute_query.return_value = _TEST_ENVISIONWARE_DATA

        main.main()

        mock_avro_encoder.encode_batch.assert_called_once_with(_RESULTS)
        mock_obfuscate.assert_has_calls(
            [
                mocker.call("1"),
                mocker.call("2"),
                mocker.call("3"),
                mocker.call("4"),
                mocker.call("barcode barcode1"),
                mocker.call("barcode barcode2"),
                mocker.call("barcode barcode3"),
                mocker.call("barcode barcode4"),
            ]
        )
