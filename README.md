PCReservePoller

The PCReservePoller periodically checks for new patron reservations on PC's, merges this information with patron data,
and obfuscates identifying patron information.

... More to come ...

SETTING UP

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
docker container run -v ~/.aws/credentials:/root/.aws/credentials:ro --env-file env_files/local_env pc-reserve-poller:latest
```

CONTRIBUTING

- branch from main
- merge into main
- merge into qa, production for deployment
- CI/CD is configured
