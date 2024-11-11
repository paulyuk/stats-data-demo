#!/usr/bin/env python

import os

from llama_index.core.query_engine import NLSQLTableQueryEngine
from sqlalchemy import create_engine, text

from llama_index.core import SQLDatabase
#from llama_index.llms.openai import OpenAI
from llama_index.llms.azure_openai import AzureOpenAI
from llama_index.embeddings.azure_openai import AzureOpenAIEmbedding




from llama_index.core.indices.struct_store.sql_query import (
    SQLTableRetrieverQueryEngine,
)
from llama_index.core.objects import (
    SQLTableNodeMapping,
    ObjectIndex,
    SQLTableSchema,
)
from llama_index.core import VectorStoreIndex


import asyncio
import asyncpg
import logging
logging.basicConfig(level=logging.DEBUG)

# Set up the OpenAI API key
OPENAI_ENDPOINT = os.getenv("OPENAI_ENDPOINT")
OPENAI_KEY = os.getenv("OPENAI_KEY")
DATABASE_ENDPOINT = os.getenv("DATABASE_ENDPOINT", None)
logging.info(f"DATABASE_ENDPOINT: {DATABASE_ENDPOINT[:20]}...")
logging.info(f"OPENAI_ENDPOINT: {OPENAI_ENDPOINT[:20]}...")


# Define the database schema and sample data
"""
database_schema = {
    "users": ["id", "name", "email"],
    "orders": ["id", "user_id", "product", "quantity", "price"]
}

sample_data = {
    "users": [
        {"id": 1, "name": "John Doe", "email": "john@example.com"},
        {"id": 2, "name": "Jane Smith", "email": "jane@example.com"}
    ],
    "orders": [
        {"id": 1, "user_id": 1, "product": "Laptop", "quantity": 1, "price": 1000},
        {"id": 2, "user_id": 2, "product": "Phone", "quantity": 2, "price": 500}
    ]
}
"""

async def assemble_query_engine_seed():
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
    print(f"database_schema: {database_schema}")
    print(f"sample_data: {sample_data}")
    return database_schema, sample_data



def _setup_models():
    from llama_index.core import Settings

    deployment_name = "ignitedemo8751329063"
    model = "gpt-4o-mini"
    llm = AzureOpenAI(
        # TODO: change this to a ENV var
        deployment_name=model,
        model=model,
        api_key=OPENAI_KEY,
        azure_endpoint=OPENAI_ENDPOINT,
        api_version="2024-08-01-preview",
    )
    Settings.llm = llm

    # https://ignitedemo8751329063.openai.azure.com/openai/deployments/text-embedding-ada-002/embeddings?api-version=2023-05-15
    model = "text-embedding-ada-002"
    embed_model = AzureOpenAIEmbedding(
        model=model,
        deployment_name=model,
        api_key=OPENAI_KEY,
        azure_endpoint=OPENAI_ENDPOINT,
        api_version="2023-05-15"
    )
    Settings.embed_model = embed_model
    



def setup_query_engine(schema, data):

    _setup_models()
    engine = create_engine(DATABASE_ENDPOINT)
    sql_database = SQLDatabase(engine, include_tables=schema.keys())

    # build out indexer compatible objects
    table_node_mapping = SQLTableNodeMapping(sql_database)
    
    table_schema_objs = []
    tables = schema.keys()
    for table in tables:
        logging.info(f"table: {table} with description: {schema[table]['description']}")
        table_schema_objs.append((SQLTableSchema(table_name=table, context_str=schema[table]['description'])))

    obj_index = ObjectIndex.from_objects(
        table_schema_objs,
        table_node_mapping,
        VectorStoreIndex,
    )
    #query_engine = SQLTableRetrieverQueryEngine(
    #    sql_database, obj_index.as_retriever(similarity_top_k=1)
    #)

    # Create the NLSQLTableQueryEngine
    query_engine = NLSQLTableQueryEngine(
        sql_database=sql_database,
        tables=tables,
        database_schema=schema,
        sample_data=data
    )
    return query_engine

    

# Function to execute a text-to-SQL query
def execute_query(natural_language_query):
    sql_query = query_engine.generate_sql(natural_language_query)
    print(f"Generated SQL Query: {sql_query}")
    result = query_engine.execute_sql(sql_query)
    return result


def text2sql_query():
    schema, data = asyncio.run(assemble_query_engine_seed())
    query_engine = setup_query_engine(schema, data)
    res = query_engine.query("which players where born in 1800s?")
    print("=="*20)
    print(res)
    print("=="*20)


# Example usage
if __name__ == "__main__":
    logging.info("Starting the text-to-SQL engine...")
    text2sql_query()
    logging.info("Text-to-SQL engine completed.")
    sleep(1000)