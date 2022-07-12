# PCReservePoller

The PCReservePoller periodically checks for new patron reservations on PC's, merges this information with patron data, obfuscates identifying patron information, and writes the result to PcReserve kinesis streams for ingest into [BIC](https://github.com/NYPL/BIC)

## Setup

- git clone
- cd into the relevant directory
- make sure docker is running
- make sure you have aws credentials configured. To run locally, you must either
  - set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in your local env file ( typically `local_env`)
  - or set `AWS_PROFILE` in your local env file. You must have this profile configured (check ~/.aws/credentials)
- check your local env file has all the other relevant variables set
- build docker image e.g.
```
docker image build  -t pc-reserve-poller:latest .
```

- run docker command e.g
```
docker container run -e ENVIRONMENT=[environment] -e AWS_ACCESS_KEY_ID=[aws access key] -e AWS_SECRET_ACCESS_KEY=[aws secret access key] pc-reserve-poller:local
```
- To update, follow the instructions on AWS and then run

```
aws ecs update-service --cluster pc-reserve-poller-qa --service pc-reserve-poller-app-qa --force-new-deployment --profile nypl-digital-dev
```

## Contributing

- branch from main
- merge into main
- merge into qa, production for deployment
- CI/CD is configured
