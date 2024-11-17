# Baseball Agent Endpoint

This app does the following:

* Environment Setup: Loads environment variables from a .env file and initializes OpenAI models for natural language processing and embeddings.
* Database Initialization: Connects to a PostgreSQL database on startup to retrieve schema and sample data, storing this information in the application state.
* Query Engine Setup: Initializes a query engine using the retrieved database schema and sample data, enabling natural language to SQL query translation.
* Agent Configuration: Configures an OpenAI agent with tools for evaluating and querying historical baseball data, making it ready to handle inference requests.
* API Endpoints: Provides endpoints for model inference and health checks, allowing users to query the agent and check the application's status.


# Exercising the Agent

The agent can be used by running the following command:

```bash
curl -X POST "http://localhost:8000/inference" \
     -H "Content-Type: application/json" \
     -d '{"query": "Which players were born in the 1800s?"}'
```

# Model Inventory Sample

NAME                      ID              SIZE      MODIFIED          
bge-large:latest          b3d71c928059    670 MB    13 minutes ago       
llama3.1:405b             65fa6b82bfda    228 GB    About an hour ago    
mixtral:8x22b             e8479ee1cb51    79 GB     2 hours ago          
mixtral:latest            d39eb76ed9c5    26 GB     5 hours ago          
dolphin-mixtral:latest    cfada4ba31c7    26 GB     5 hours ago          
llama3.2:latest           a80c4f17acd5    2.0 GB    5 hours ago          
sqlcoder:7b               77ac14348387    4.1 GB    47 hours ago   


# Differnet Model Behaviours 

"sqlcoder:7b"
{"response":"\n\nThe following query returns all players who were born in the 1800s.\n\n```sql\nSELECT p.first_name, p.last_name FROM player p WHERE to_number(p.date_of_birth,'9999') BETWEEN 1800 AND 1899;\n```"}


**dolphin-mixtral:latest**

Thought: The current language of the user is: English. I need to use a tool to help me answer the question.
Action: historical-baseball-stats
Action Input: {'properties': AttributedDict([('input', 'birth_year:[1800,1900]')]), 'required': ['input'], 'type': 'object'}


Observation:  Based on the input query, it seems you are looking for information about players born between 1800 and 1900. The SQL query provided is not valid due to a mismatch in data types. To resolve this issue, you can try casting the birth year column as an integer before applying the BETWEEN operator:

```sql
SELECT t.playerid, t.namefirst, t.namelast, t.birthyear::integer
FROM test_master_csv t
WHERE (t.birthyear::integer) BETWEEN 1800 AND 1900;
```

This should return the requested information about players born between 1800 and 1900, assuming that the data is stored in a table named "test_master_csv" with columns "playerid", "namefirst", "namelast", and "birthyear".


> Running step bde46708-db23-4cba-8f5b-2d6155462f00. Step input: None


Thought: I can answer without using any more tools. I'll use the user's language to answer
Answer: There were no professional baseball players born in the 1800s, as the first professional baseball team was established in 1869. The historical-baseball-stats tool does not contain data on players from that time period.



**mixtral:latest**

Thought: The current language of the user is: English. I need to use a tool to help me answer the question.
Action: historical-baseball-stats
Action Input: {'properties': AttributedDict([('input', AttributedDict([('title', 'Input'), ('type', 'string')]))]), 'required': ['input'], 'type': 'object', 'input': 'players born in the 1800s'}


Observation:  The players born in the 1800s are:

* John Abadie
* Ed Abbaticchio
* Bert Abbey
* Charlie Abbey
* Dan Abbott
* Fred Abbott
* Ody Abbott
* Frank Abercrombie

These are the individuals who made a mark in the field of sports, having been born in the 1800s, highlighting their dedication and talent despite the challenging circumstances of that era.

Thought: I can answer without using any more tools. I'll use the user's language to answer.
Answer: The players born in the 1800s are John Abadie, Ed Abbaticchio, Bert Abbey, Charlie Abbey, Dan Abbott, Fred Abbott, Ody Abbott, and Frank Abercrombie.



**llama3.1:405b**

DEBUG:llama_index.core.indices.struct_store.sql_retriever:> Predicted SQL query: SELECT namefirst, namelast, birthyear
FROM test_master_csv
WHERE birthyear BETWEEN '1800' AND '1899'
ORDER BY birthyear;


Got output: Here are some players who were born in the 1800s:

1. Frank Abercrombie - Born in 1850
2. John Abadie - Born in 1854
3. Dan Abbott - Born in 1862
4. Charlie Abbey - Born in 1866
5. Bert Abbey - Born in 1869
6. Fred Abbott - Born in 1874
7. Ed Abbaticchio - Born in 1877
8. Ody Abbott - Born in 1888

If you need more information about any of these players, feel free to ask!



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
  