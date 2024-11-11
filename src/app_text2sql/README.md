# Summary

Work in progress. This simple script currently only answers one question: "Which players where born in 1800s?"



# Setup

App needs the following environment variables:

```
DATABASE_ENDPOINT='postgresql://<username>:<password>@<instance_name>.postgres.database.azure.com:5432/<database_name>'
OPENAI_ENDPOINT="https://<deployment_name>.openai.azure.com/"
OPENAI_KEY="<your_api_key>"
```


# Build & Run

```
docker build -t simple_text2sql .
docker run \
      -e DATABASE_ENDPOINT='<your_endpoint>' \
      -e OPENAI_ENDPOINT='<your_endpoint>' \
      -e OPENAI_KEY='<your_endpoint>' \
      -t simple_text2sql
```