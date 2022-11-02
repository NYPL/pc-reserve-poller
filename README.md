# PCReservePoller

The PCReservePoller periodically checks for new patron reservations on PCs, merges this information with patron data, obfuscates identifying patron information, and writes the result to PcReserve Kinesis streams for ingest into the [BIC](https://github.com/NYPL/BIC).

## Running locally
- `cd` into this directory
- Check the environment file you will be using to ensure it has all the relevant variables set (see below for more info on these variables)
  - Add your AWS credentials (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) to this file to avoid having to manually `export` them. Be very careful not to commit the file with your credentials, though!
- Use one of the two methods below to start the app and then check the output logs and the [QA Kinesis stream](https://us-east-1.console.aws.amazon.com/kinesis/home?region=us-east-1#/streams/details/CircTransAnon-qa/monitoring) in AWS to see the results of your run

Using Pry:
- Run `bundle install` to install all the Ruby requirements (this only needs to be done once ever)
- Run `export ENVIRONMENT=<env>` to set the app to read the environment variables from your chosen environment file. `<env>` should be the filename without the `_env` suffix- Run `pry` from the command line to enter a Ruby session
- Individual methods/files can be tested this way, but to run the whole app, run:
```ruby
require_relative 'app.rb'
handle_event(event: {}, context: {})
```

Using Docker:
- Make sure Docker is running and then build the Docker image (don't forget the period):
```
docker image build -t pc-reserve-poller:local .
```

- Start up the Docker container, where `<env>` should be your chosen environment filename without the `_env` suffix:
```
docker container run -e ENVIRONMENT=<env> pc-reserve-poller:local
```

## Git workflow
This repo uses the [Main-QA-Production](https://github.com/NYPL/engineering-general/blob/main/standards/git-workflow.md#main-qa-production) git workflow.

[`main`](https://github.com/NYPL/bic-circ-trans-poller/tree/main) has the latest and greatest commits, [`qa`](https://github.com/NYPL/bic-circ-trans-poller/tree/qa) has what's in our QA environment, and [`production`](https://github.com/NYPL/bic-circ-trans-poller/tree/production) has what's in our production environment.

### Ideal Workflow
- Cut a feature branch off of `main`
- Commit changes to your feature branch
- File a pull request against `main` and assign a reviewer
- After the PR is accepted, merge into `main`
- Merge `main` > `qa`
- Deploy app to QA (must be done manually -- see below) and confirm it works
- Merge `qa` > `production`
- Deploy app to production (must be done manually -- see below) and confirm it works

## Deployment
The poller is deployed as an AWS ECS service to [qa](https://us-east-1.console.aws.amazon.com/ecs/home?region=us-east-1#/clusters/pc-reserve-poller-qa/services) and [prod](https://us-east-1.console.aws.amazon.com/ecs/home?region=us-east-1#/clusters/pc-reserve-poller-production/services) environments. To upload a new version of this service, you must have the `nypl-digital-dev` AWS profile set up. Note that the first four instructions in both sections are based on the instructions seen when you click the **"View push commands"** button on the [AWS Elastic Container Registry page](https://us-east-1.console.aws.amazon.com/ecr/repositories/private/946183545209/pc-reserve-poller?region=us-east-1) but with slight modifications.

To deploy to QA, make sure your command line is in the `qa` branch of the repo and follow the instructions below.

To deploy to production, make sure your command line is in the `production` branch of the repo and follow the instructions below, but replace every instance of `qa` in the commands with `production`.

```bash
1. aws ecr get-login-password --region us-east-1 --profile nypl-digital-dev | docker login --username AWS --password-stdin 946183545209.dkr.ecr.us-east-1.amazonaws.com

2. docker build -t pc-reserve-poller .

3. docker tag pc-reserve-poller:latest 946183545209.dkr.ecr.us-east-1.amazonaws.com/pc-reserve-poller:qa-latest

4. docker push 946183545209.dkr.ecr.us-east-1.amazonaws.com/pc-reserve-poller:qa-latest

5. aws ecs update-service --cluster pc-reserve-poller-qa --service pc-reserve-poller-app-qa --force-new-deployment --region us-east-1 --profile nypl-digital-dev

# This command will manually trigger the poller to run. This should not be run if you want to wait for the next scheduled event.
6. aws ecs run-task --cluster pc-reserve-poller-qa --task-definition pc-reserve-poller-app-qa:14 --count 1 --region us-east-1 --profile nypl-digital-dev
```

## Environment Variables
The first 28 variables in each environment file in the `env_files` directory (every variable through `KINESIS_BATCH_SIZE`) are required by the poller to run. There are then five additional optional variables that can be used for development purposes. Note that the `qa_env` and `production_env` files are actually read by the deployed service, so do not change these files unless you want to change how the service will behave in the wild -- these are not meant for local testing.

| Name        | Notes           |
| ------------- | ------------- |
| `NYPL_OAUTH_ID` | Encrypted NYPL OAUTH client id. Required by Platform API. |
| `NYPL_OAUTH_SECRET` | Encrypted NYPL OAUTH client secret. Required by Platform API. |
| `NYPL_OAUTH_URL` | Always `https://isso.nypl.org/`. Required by Platform API. |
| `PLATFORM_API_BASE_URL` | Always `https://platform.nypl.org/api/v0.1/`. Required by Platform API. |
| `ENVISIONWARE_DB_HOST` | Encrypted Envisionware host. There is no QA Envisionware, so this is always the same. |
| `ENVISIONWARE_DB_PORT` | Always `3306` |
| `ENVISIONWARE_DB_NAME` | Always `lasttwodays` | 
| `ENVISIONWARE_DB_USER` | Encrypted Envisionware user. There is only one user, so this is always the same. |
| `ENVISIONWARE_DB_PASSWORD` | Encrypted Envisionware password for the user. There is only one user, so this is always the same. |
| `ENVISIONWARE_TABLE_NAME` | Always `strad_bci` |
| `SIERRA_DB_HOST` | Encrypted Sierra host (either test, QA, or prod) |
| `SIERRA_DB_PORT` | Always `1032` |
| `SIERRA_DB_NAME` | Always `iii` |
| `SIERRA_DB_USER` | Encrypted Sierra user. There is only one user, so this is always the same. |
| `SIERRA_DB_PASSWORD` | Encrypted Sierra password for the user. There is only one user, so this is always the same. |
| `BCRYPT_SALT` | Encrypted bcrypt salt |
| `SCHEMA_TYPE` | Always `PcReserve`. Name of the Avro schema used by the Kinesis client to serialize the data. |
| `KINESIS_STREAM_NAME` | Name of the Kinesis stream to send the data to (either `PcReserve-qa` or `PcReserve-production`) |
| `S3_AWS_REGION` | Always `us-east-1`. The AWS region with which to set up the S3 client. |
| `S3_BASE_URL` | URL of the S3 cache to read from. This differs between QA and prod and should be empty when not using the cache locally. |
| `S3_RESOURCE` | Name of the resource for the S3 cache. This differs between QA and prod and should be empty when not using the cache locally. |
| `S3_BUCKET_NAME` | Bucket of the S3 cache to write to. This differs between QA and prod and should be empty when not using the cache locally. |
| `LOG_LEVEL` | What level of logs should be output |
| `PATRON_ENDPOINT` | Always `patrons` |
| `PATRON_BATCH_SIZE` | How many barcodes should be sent to Platform at once. Due to Platform limitations, this must be `1`. |
| `ENVISIONWARE_BATCH_SIZE` | How many rows should be queried from Envisionware at once |
| `SIERRA_BATCH_SIZE` | How many patron ids should be sent to Sierra at once |
| `KINESIS_BATCH_SIZE` | How many records should be sent to Kinesis at once |
| `MAX_BATCHES` (optional) | How many queries to Envisionware should be made before stopping. If this is empty, the app will continue until all Envisionware rows have been processed. |
| `PCR_KEY_START` (optional) | What `pcr_key` should the app start querying Envisionware from. If this is empty, the app will use the cache to determine this. If this is set, `PCR_DATE_TIME_START` must also be set and `UPDATE_STATE` should be set to false -- otherwise the cache will be overridden with the starting parameters. |
| `PCR_DATE_TIME_START` (optional) | What `pcr_date_time` should the app start querying Envisionware from. If this is empty, the app will use the cache to determine this. If this is set, `PCR_KEY_START` must also be set and `UPDATE_STATE` should be set to false -- otherwise the cache will be overridden with the starting parameters. |
| `UPDATE_STATE` (optional) | Whether or not to read and write from the cache. If this is empty, the app will use the cache. This should almost certainly be set to `false` when running locally. |
| `LOG_PATH` (optional) | Where the logs should be output to. If this is empty, STDOUT will be used. |
