# PcReservePoller

The PcReservePoller periodically checks for new patron reservations on PCs, merges this information with patron data from Sierra and Redshift, obfuscates identifying patron information, and writes the result to PcReserve Kinesis streams for ingest into the [BIC](https://github.com/NYPL/BIC).

## Running locally
* Add your `AWS_PROFILE` to the config file for the environment you want to run
  * Alternatively, you can manually export it (e.g. `export AWS_PROFILE=<profile>`)
* Run `ENVIRONMENT=<env> python3 main.py`
  * `<env>` should be the config filename without the `.yaml` suffix. Note that running the poller with `production.yaml` will actually send records to the production Kinesis stream -- it is not meant to be used for development purposes.
  * `make run` will run the poller in using the development environment
* Alternatively, to build and run a Docker container, run:
```
docker image build -t pc-reserve-poller:local .

docker container run -e ENVIRONMENT=<env> -e AWS_ACCESS_KEY_ID=<> -e AWS_SECRET_ACCESS_KEY=<> pc-reserve-poller:local
```

## Git workflow
This repo uses the [Main-QA-Production](https://github.com/NYPL/engineering-general/blob/main/standards/git-workflow.md#main-qa-production) git workflow.

[`main`](https://github.com/NYPL/pc-reserve-poller/tree/main) has the latest and greatest commits, [`qa`](https://github.com/NYPL/pc-reserve-poller/tree/qa) has what's in our QA environment, and [`production`](https://github.com/NYPL/pc-reserve-poller/tree/production) has what's in our production environment.

### Ideal Workflow
- Cut a feature branch off of `main`
- Commit changes to your feature branch
- File a pull request against `main` and assign a reviewer
  - In order for the PR to be accepted, it must pass all unit tests, have no lint issues, and update the CHANGELOG (or contain the Skip-Changelog label in GitHub)
- After the PR is accepted, merge into `main`
- Merge `main` > `qa`
- Deploy app to QA and confirm it works
- Merge `qa` > `production`
- Deploy app to production and confirm it works

## Deployment
The poller is deployed as an AWS ECS service to [qa](https://us-east-1.console.aws.amazon.com/ecs/home?region=us-east-1#/clusters/pc-reserve-poller-qa/services) and [prod](https://us-east-1.console.aws.amazon.com/ecs/home?region=us-east-1#/clusters/pc-reserve-poller-production/services) environments. To upload a new QA version of this service, create a new release in GitHub off of the `qa` branch and tag it `qa-vX.X.X`. The GitHub Actions deploy-qa workflow will then deploy the code to ECR and update the ECS service appropriately. To deploy to production, create the release from the `production` branch and tag it `production-vX.X.X`. To trigger the app to run immediately (rather than waiting for the next scheduled event), run:
```bash
# In production, use pc-reserve-poller-app-production:1 for the task definition
aws ecs run-task --cluster pc-reserve-poller-qa --task-definition pc-reserve-poller-app-qa:14 --count 1 --region us-east-1 --profile nypl-digital-dev
```

## Environment variables
The first 11 unencrypted variables (every variable through `KINESIS_BATCH_SIZE`) plus all of the encrypted variables in each environment file are required by the poller to run. There are then eight additional optional variables that can be used for development purposes -- `devel.yaml` sets each of these. Note that the `qa.yaml` and `production.yaml` files are actually read by the deployed service, so do not change these files unless you want to change how the service will behave in the wild -- these are not meant for local testing.

| Name        | Notes           |
| ------------- | ------------- |
| `AWS_REGION` | Always `us-east-1`. The AWS region used for the Redshift, S3, KMS, and Kinesis clients. |
| `ENVISIONWARE_DB_PORT` | Always `3306` |
| `ENVISIONWARE_DB_NAME` | Always `lasttwodays` | 
| `ENVISIONWARE_DB_HOST` | Encrypted Envisionware host. There is no QA Envisionware, so this is always the same. |
| `ENVISIONWARE_DB_USER` | Encrypted Envisionware user |
| `ENVISIONWARE_DB_PASSWORD` | Encrypted Envisionware password for the user |
| `SIERRA_DB_PORT` | Always `1032` |
| `SIERRA_DB_NAME` | Always `iii` |
| `SIERRA_DB_HOST` | Encrypted Sierra host (either test, QA, or prod) |
| `SIERRA_DB_USER` | Encrypted Sierra user |
| `SIERRA_DB_PASSWORD` | Encrypted Sierra password for the user |
| `REDSHIFT_DB_NAME` | Which Redshift database to query (either `dev`, `qa`, or `production`) |
| `REDSHIFT_DB_HOST` | Encrypted Redshift cluster endpoint |
| `REDSHIFT_DB_USER` | Encrypted Redshift user |
| `REDSHIFT_DB_PASSWORD` | Encrypted Redshift password for the user |
| `KINESIS_STREAM_ARN` | Encrypted ARN for the Kinesis stream the poller sends the encoded data to |
| `BCRYPT_SALT` | Encrypted bcrypt salt |
| `S3_BUCKET` | S3 bucket for the cache. This differs between QA and prod and should be empty when not using the cache locally. |
| `S3_RESOURCE` | Name of the resource for the S3 cache. This differs between QA and prod and should be empty when not using the cache locally. |
| `PC_RESERVE_SCHEMA_URL` | Platform API endpoint from which to retrieve the PcReserve Avro schema |
| `KINESIS_BATCH_SIZE` | How many records should be sent to Kinesis at once. Kinesis supports up to 500 records per batch. |
| `LOG_LEVEL` (optional) | What level of logs should be output. Set to `info` by default. |
| `MAX_BATCHES` (optional) | The maximum number of times the poller should poll Envisionware per session. If this is not set, the poller will continue querying until all new records in Envisionware have been processed. |
| `IGNORE_CACHE` (optional) | Whether fetching and setting the state from S3 should not be done. If this is true, the `PCR_DATE_TIME` and `PCR_KEY` environment variables will be used for the initial state (or `2023-01-01 00:00:00 +0000` and `0` by default). |
| `IGNORE_KINESIS` (optional) | Whether sending the encoded records to Kinesis should not be done
| `PCR_DATE_TIME` (optional) | If `IGNORE_CACHE` is true, the datetime to use in the Envisionware query. If `IGNORE_CACHE` is false, this field is not read. |
| `PCR_KEY` (optional) | If `IGNORE_CACHE` is true, the key to use in the Envisionware query. If `IGNORE_CACHE` is false, this field is not read. |