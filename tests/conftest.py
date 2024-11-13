import os
import pytest

# Sets OS vars for entire set of tests
TEST_ENV_VARS = {
    "ENVIRONMENT": "test_environment",
    "AWS_REGION": "test_aws_region",
    "ENVISIONWARE_DB_PORT": "test_envisionware_port",
    "ENVISIONWARE_DB_NAME": "test_envisionware_name",
    "ENVISIONWARE_DB_HOST": "test_envisionware_host",
    "ENVISIONWARE_DB_USER": "test_envisionware_user",
    "ENVISIONWARE_DB_PASSWORD": "test_envisionware_password",
    "SIERRA_DB_PORT": "test_sierra_port",
    "SIERRA_DB_NAME": "test_sierra_name",
    "SIERRA_DB_HOST": "test_sierra_host",
    "SIERRA_DB_USER": "test_sierra_user",
    "SIERRA_DB_PASSWORD": "test_sierra_password",
    "REDSHIFT_DB_NAME": "test_redshift_name",
    "REDSHIFT_DB_HOST": "test_redshift_host",
    "REDSHIFT_DB_USER": "test_redshift_user",
    "REDSHIFT_DB_PASSWORD": "test_redshift_password",
    "ENVISIONWARE_BATCH_SIZE": "4",
    "MAX_BATCHES": "1",
    "S3_BUCKET": "test_s3_bucket",
    "S3_RESOURCE": "test_s3_resource",
    "PC_RESERVE_SCHEMA_URL": "https://test_schema_url",
    "KINESIS_BATCH_SIZE": "4",
    "KINESIS_STREAM_ARN": "test_kinesis_stream",
    "BCRYPT_SALT": "test_salt",
}


@pytest.fixture(scope="function", autouse=True)
def tests_setup_and_teardown():
    # Will be executed before each test
    os.environ.update(TEST_ENV_VARS)

    yield

    # Will execute after each test
    for os_config in TEST_ENV_VARS.keys():
        if os_config in os.environ:
            del os.environ[os_config]
