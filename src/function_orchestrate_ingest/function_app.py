import azure.functions as func
import azure.durable_functions as df
from datetime import datetime
import json
import logging
import os
import requests
import httpx
import json
from azure.core.credentials import AzureKeyCredential
#from azure.search.documents import SearchClient
#from uuid import uuid16
from sqlalchemy import create_engine, MetaData, Table, Column, String, Integer
from sqlalchemy.dialects.postgresql import VARCHAR
import pandas as pd
import numpy as np
from sqlalchemy.engine import reflection

# TODO should this be replaced with psycopg2 (sync) to make things easier?
import asyncpg


BATCH_SIZE = 1000
SUB_BATCH_SIZE = 100

app = df.DFApp(http_auth_level=func.AuthLevel.ANONYMOUS)


# used to deliver data to the function
EVENTHUB_CONNECTION_STR = os.getenv("EVENTHUB_CONNECTION_STR", None)
EVENTHUB_NAME = os.getenv("EVENTHUB_NAME_INGEST", None)

# used to create the embedding
EMBEDDING_ENDPOINT = os.getenv("EMBEDDING_ENDPOINT", None)
EMBEDDING_KEY = os.getenv("EMBEDDING_KEY", None)

# database for our structured data
DATABASE_ENDPOINT = os.getenv("DATABASE_ENDPOINT", None)

# used to store embeddings
SEARCH_ENDPOINT= os.getenv("SEARCH_ENDPOINT", None)
SEARCH_INDEX = os.getenv("SEARCH_INDEX", None)
SEARCH_KEY = os.getenv("SEARCH_KEY", None)

# TODO: assess connection close location
DB_ENGINE = create_engine(DATABASE_ENDPOINT)


# TODO: 
# - figure out if we need to identify a primary key
# - figure out if we need to advance the event hubs cursor or if that's automatic
@app.event_hub_message_trigger(arg_name="event", 
                               event_hub_name=EVENTHUB_NAME, 
                               connection="EVENTHUB_CONNECTION_STR")
@app.durable_client_input(client_name="client")
async def durable_client_trigger(event: func.EventHubEvent, client: df.DurableOrchestrationClient):
    logging.info('EventHub triggered durable function at %s.', datetime.now())
    event_json = json.loads(event.get_body().decode("utf-8"))
    # create the table schema
    table_name = event_json['file_name']
    if not _table_exists(table_name):
        table_header = event_json['header']
        metadata_obj = MetaData()
        table = _create_table_schema(table_name, table_header, metadata_obj)
        # create the new table with the simple schema (TODO: add ability to provide better schema)
        metadata_obj.create_all(DB_ENGINE)
        logging.info(f"Table created: {table}")
    else:
        logging.info(f"Table already exists: {table_name}")
    
    SOMETHING = await client.start_new("process_statsbatch", client_input=event_json)
    #return SOMETHING


def _table_exists(table_name):
    inspector = reflection.Inspector.from_engine(DB_ENGINE)
    return inspector.has_table(table_name)


def _create_table_schema(table_name, table_header, metadata_obj):
    columns = [Column(field, VARCHAR, primary_key=(field == "playerID")) for field in table_header]
    table = Table(table_name, metadata_obj, *columns)
    return table


@app.orchestration_trigger(context_name="context")
def process_statsbatch(context: df.DurableOrchestrationContext):
    event_json = context.get_input()
    logging.info(f"Received event: {event_json}")
    data_df = pd.read_csv(event_json['file_url'])
    num_batches = int(np.ceil(len(data_df) / BATCH_SIZE))
    results = []
    for i in range(num_batches):
        logging.info(f"Kicking off batch: {1}")
        batch = data_df[i*BATCH_SIZE:(i+1)*BATCH_SIZE]
        #batchrows = [list(record.values()) for record in batch.to_dict(orient="records")]
        batchrows = batch.to_dict(orient="records")
        logging.info(f"Batch {i} has {len(batchrows)} rows and starts with {batchrows[0]}")
        event_json['batchnumber'] = i
        event_json['batchrows'] = batchrows
        res = yield context.call_activity("insert_statsbatch", event_json)
        results.append(res)


# event_json is not eventjson and has batchnumber and batchrows now
@app.activity_trigger(input_name="eventjson")
async def insert_statsbatch(eventjson: dict):
    logging.info(f"Inserting statsbatch: {eventjson['batchnumber']}")
    batchrows = eventjson['batchrows']
    table_name = eventjson['file_name']
    conn = await asyncpg.connect(DATABASE_ENDPOINT)
    try:
        # TODO: maybe switch to asyncpg.copy_records_to_table
        num_batches = int(np.ceil(len(batchrows) / SUB_BATCH_SIZE))
        logging.info(f"Inserting {len(batchrows)} rows into {table_name} in {num_batches} sub-batches")

        for i in range(num_batches):
            logging.info(f"Inserting sub-batch {i}")
            batch = [[str(value) for value in row.values()] for row in batchrows[i*BATCH_SIZE:(i+1)*BATCH_SIZE]]
            try:
                await conn.copy_records_to_table(table_name, records=batch)
            except Exception as e:
                logging.error(f"Error inserting batch: {e}")
            #columns = ', '.join(row.keys())
            #values = ', '.join(f"${i+1}" for i in range(len(row)))
            #query = f"INSERT INTO {table_name} ({columns}) VALUES ({values})"
            #await conn.execute(query, *row.values())
    finally:
        await conn.close()
    return True