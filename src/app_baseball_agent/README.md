# Baseball Agent Endpoint

This app does the following:

* Environment Setup: Loads environment variables from a .env file and initializes OpenAI models for natural language processing and embeddings.
* Database Initialization: Connects to a PostgreSQL database on startup to retrieve schema and sample data, storing this information in the application state.
* Query Engine Setup: Initializes a query engine using the retrieved database schema and sample data, enabling natural language to SQL query translation.
* Agent Configuration: Configures an OpenAI agent with tools for evaluating and querying historical baseball data, making it ready to handle inference requests.
* API Endpoints: Provides endpoints for model inference and health checks, allowing users to query the agent and check the application's status.


# Build and Run

This app uses `.env.dev` file for local settings. A sample is included in `sample.dotenv`. If you intend on running this application locally (without Docker) populate the file accordingly and rename to `.env.dev`.

```
# build
docker build -t baseball_agent .

# run
docker run \
        -e OPENAI_MODEL="<your_model>" \
        -e OPENAI_API_KEY="<your_key>" \
        -e OPENAI_ENDPOINT="https://<your_deployment>.openai.azure.com/" \
        -e OPENAI_API_VERSION="2024-08-01-preview" \
        -e EMBEDDING_MODEL="text-embedding-ada-002" \
        -e EMBEDDING_API_VERSION="2023-05-15" \
        -e DATABASE_ENDPOINT="<your_connection_string>" \
        -t baseball_agent
```


# TODO

* Add a local model instead of relying on OpenAI
  