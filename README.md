# inspec-reporter-honeycomb

## install

You can install using cinc-auditor or inspec with:

`inspec plugin install inspec-reporter-honeycomb`

or

`cinc-auditor plugin install inspec-reporter-honeycomb`

## Required environment variables

You must set two environment variables:

```bash
export HONEYCOMB_API_KEY="<your API key>"
export HONEYCOMB_API_URL="https://api.honeycomb.io/1/batch/<your dataset name>"
```

## Run with the new reporter

```bash
inspec exec <PROFILE_NAME> --reporter honeycomb
```

Please ensure you replace the api key and dataset name in the URL.

Without these you'll receive a cryptic error about `bad argument (expected URI object or URI string)`
