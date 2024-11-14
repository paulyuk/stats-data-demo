from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import openai
import os
from dotenv import load_dotenv
from llama_index.core import Settings
from llama_index.llms.azure_openai import AzureOpenAI
from llama_index.agent.openai import OpenAIAgent
from llama_index.embeddings.azure_openai import AzureOpenAIEmbedding
from llama_index.core.evaluation import RelevancyEvaluator
from llama_index.core.tools import ToolMetadata
from llama_index.core.tools.eval_query_engine import EvalQueryEngineTool
from sqlalchemy import create_engine, text
import asyncpg
from llama_index.core import SQLDatabase
from helper_tools import CustomAzureCodeInterpreterToolSpec

from llama_index.core.indices.struct_store.sql_query import SQLTableRetrieverQueryEngine
from llama_index.core.objects import SQLTableNodeMapping, ObjectIndex, SQLTableSchema
from llama_index.core.query_engine import NLSQLTableQueryEngine
from llama_index.core import VectorStoreIndex


import logging
logging.basicConfig(level=logging.DEBUG)

load_dotenv(dotenv_path='.env.dev')
# Extract settings from environment variables
OPENAI_MODEL = os.getenv("OPENAI_MODEL")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_ENDPOINT = os.getenv("OPENAI_ENDPOINT")
OPENAI_API_VERSION = os.getenv("OPENAI_API_VERSION")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL")
EMBEDDING_API_VERSION = os.getenv("EMBEDDING_API_VERSION")
DATABASE_ENDPOINT = os.getenv("DATABASE_ENDPOINT")
SESSIONS_ENDPOINT = os.getenv("SESSIONS_ENDPOINT")


class InferenceRequest(BaseModel):
    query: str

class InferenceResponse(BaseModel):
    response: str


def _setup_models():
    # Initialize the AzureOpenAI model
    llm = AzureOpenAI(
        deployment_name=OPENAI_MODEL,
        model=OPENAI_MODEL,
        api_key=OPENAI_API_KEY,
        azure_endpoint=OPENAI_ENDPOINT,
        api_version=OPENAI_API_VERSION,
    )
    Settings.llm = llm

    # Initialize the AzureOpenAIEmbedding model
    embed_model = AzureOpenAIEmbedding(
        model=EMBEDDING_MODEL,
        deployment_name=EMBEDDING_MODEL,
        api_key=OPENAI_API_KEY,
        azure_endpoint=OPENAI_ENDPOINT,
        api_version=EMBEDDING_API_VERSION,
    )
    Settings.embed_model = embed_model



logging.info(f"Setting up openai model: {OPENAI_MODEL}")
_setup_models()
logging.info(f"OpenAI model setup complete.")

app = FastAPI()


# retrieve the schema and sample data from the database
@app.on_event("startup")
async def _assemble_query_engine_seed():
    # Connect to the database
    conn = await asyncpg.connect(DATABASE_ENDPOINT)

    # Get the table names
    table_names = await conn.fetch("SELECT table_name FROM information_schema.tables WHERE table_schema='public'")
    logging.info(f"table_names: {table_names}")

    # Get the column names for each table
    database_schema = {}
    sample_data = {}
    for table in table_names:
        table_name = table["table_name"]
        logging.info(f"fetching schema for table_name: {table_name}")
        database_schema[table_name] = {}
        column_names = await conn.fetch(f"SELECT column_name FROM information_schema.columns WHERE table_name='{table_name}'")
        database_schema[table_name]["schema"] = [column["column_name"] for column in column_names]
        table_description = await conn.fetch(f"SELECT obj_description(relfilenode, 'pg_class') AS table_comment FROM pg_class WHERE relname = '{table_name}' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');")
        if table_description:
            database_schema[table_name]["description"] = table_description[0]["table_comment"]
        else:
            database_schema[table_name]["description"] = "No description available"
        sample_data[table_name] = await conn.fetch(str(text(f'SELECT * FROM "{table_name}" LIMIT 5')))

    # Close the database connection
    await conn.close()
    logging.info(f"database_schema: {database_schema}")
    logging.info(f"sample_data: {sample_data}")

    # Store the data in the application state
    app.state.database_schema = database_schema
    app.state.sample_data = sample_data


@app.on_event("startup")
async def _setup_query_engine():
    schema = app.state.database_schema
    sample_data = app.state.sample_data
    engine = create_engine(DATABASE_ENDPOINT)
    sql_database = SQLDatabase(engine, include_tables=schema.keys())

    # build out indexer compatible objects
    table_node_mapping = SQLTableNodeMapping(sql_database)
    
    table_schema_objs = []
    tables = schema.keys()
    for table in tables:
        logging.info(f"table: {table} with description: {schema[table]['description']}")
        table_schema_objs.append((SQLTableSchema(table_name=table, context_str=schema[table]['description'])))

    # just use an in-memory index for now
    obj_index = ObjectIndex.from_objects(
        table_schema_objs,
        table_node_mapping,
        VectorStoreIndex,
    )

    # Create the NLSQLTableQueryEngine
    query_engine = NLSQLTableQueryEngine(
        sql_database=sql_database,
        tables=tables,
        database_schema=schema,
        sample_data=sample_data,
    )
    logging.info(f"Query engine ready!")
    app.state.query_engine = query_engine


@app.on_event("startup")
def _setup_tools_and_agent():

    evaluator = RelevancyEvaluator()
    """
    image_fetcher_metadata = ToolMetadata(
        name="image-fetcher",
        description=(
            "Use this to fetch an image, write python code to fetch the image from https://www.baseball-reference.com/players/a/{PLAYERID}.shtml. Where PLAYERID is the playerid from the database. Download all the images which have /images/headshots/ as part of their directory location and save them in /data. The tool returns the result, stdout and stderr."
        ),
    )
    """

    #image_fetcher = CustomAzureCodeInterpreterToolSpec(
    #    pool_management_ID is the playerid from the database. Download all the images which have /images/headshots/ as part of their directory location and save them in /data. The tool returns the result, stdout and stderr."

    tools = [
        EvalQueryEngineTool(
            evaluator=evaluator,
            query_engine=app.state.query_engine,
            metadata=ToolMetadata(
                name="historical-baseball-stats",
                description=(
                    "Provides baseball data on players, teams, batts and many more for the years 1871-2015."
                ),
            ),
        ),
    ]
    #tools.append(image_fetcher)
 
    agent = OpenAIAgent.from_tools(tools, verbose=True)
    app.state.agent = agent


@app.post("/inference", response_model=InferenceResponse, tags=["Inference"])
async def model_inference(request: InferenceRequest):
    agent = app.state.agent
    try:
        response = await agent.achat(request.query)
        return InferenceResponse(response=response.response)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "healthy"}