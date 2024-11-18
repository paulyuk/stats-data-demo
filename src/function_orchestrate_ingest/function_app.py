import azure.functions as func
import azure.durable_functions as df
from datetime import datetime
import json
import logging
import os
import io
import json
from azure.core.credentials import AzureKeyCredential
#from azure.search.documents import SearchClient
#from uuid import uuid16
from sqlalchemy import create_engine, MetaData, Table, Column, String, Integer
from sqlalchemy.dialects.postgresql import VARCHAR
import pandas as pd
import numpy as np
from sqlalchemy.engine import reflection
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
from io import BytesIO

# TODO should this be replaced with psycopg2 (sync) to make things easier?
import asyncpg

logging.basicConfig(level=logging.DEBUG)

BATCH_SIZE = os.getenv("BATCH_SIZE", 1000)
SUB_BATCH_SIZE = os.getenv("SUB_BATCH_SIZE", 100)

app = df.DFApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# check auth first
DEFAULT_CREDENTIAL = DefaultAzureCredential(managed_identity_client_id=os.getenv('AZURE_CLIENT_ID', None))
if not DEFAULT_CREDENTIAL:
    logging.error(f"Missing managed identity client ID!")
    raise ValueError("Missing managed identity client ID!")

STORAGE_ACCOUNT_NAME = os.getenv('AzureWebJobsStorage__accountName', None)
DATABASE_ENDPOINT = os.getenv("DATABASE_ENDPOINT", None)
STORAGE_CONTAINER_CSV = os.getenv("STORAGE_CONTAINER_CSV")

# check the other services
if not STORAGE_ACCOUNT_NAME or not DATABASE_ENDPOINT or not STORAGE_CONTAINER_CSV:
    logging.error(f"Missing required environment variables!")
    logging.error(f"STORAGE_ACOUNT_NAME: {STORAGE_ACCOUNT_NAME}")
    logging.error(f"DATABASE_ENDPOINT: {DATABASE_ENDPOINT}")
    logging.error(f"STORAGE_CONTAINER_CSV: {STORAGE_CONTAINER_CSV}")
    raise ValueError("Missing required environment variables!")

STORAGE_ACCOUNT_URL = f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
BLOB_SERVICE_CLIENT = BlobServiceClient(STORAGE_ACCOUNT_URL, credential=DEFAULT_CREDENTIAL)

# this is only used at the beginning, we use async later in the event loop
DB_ENGINE = create_engine(DATABASE_ENDPOINT)

# TODO: 
# - figure out if we need to identify a primary key
@app.service_bus_queue_trigger(arg_name="message", 
                               queue_name="%FULL_FILE_SERVICEBUS_QUEUE_NAME%", 
                               connection="SERVICEBUS_CONNECTION")
@app.durable_client_input(client_name="client")
async def durable_client_trigger(message: func.ServiceBusMessage, client: df.DurableOrchestrationClient):
    logging.info('Service Bus triggered durable function at %s.', datetime.now())
    event_json = json.loads(message.get_body().decode("utf-8"))

    # create the table schema
    table_name = event_json['table_name']
    table_description = event_json['file_description']
    if not _table_exists(table_name):
        table_header = event_json['header']
        metadata_obj = MetaData()
        table = _create_table_schema(table_name, table_header, table_description, metadata_obj)
        # create the new table with the simple schema (TODO: add ability to provide better schema)
        metadata_obj.create_all(DB_ENGINE)
        logging.info(f"Table created: {table}")
    else:
        logging.info(f"Table already exists: {table_name}")
    DB_ENGINE.dispose()
    SOMETHING = await client.start_new("process_statsbatch", client_input=event_json)


def _table_exists(table_name):
    inspector = reflection.Inspector.from_engine(DB_ENGINE)
    return inspector.has_table(table_name)


def _create_table_schema(table_name, table_header, table_description, metadata_obj):
    # Take LLM inference of table schema out for now
    """
    prompt = f"Create a table schema for a CSV with the following header row: {table_header}." \
              "The CSV contains the following data: {table_description}." \
              "Based on this description and the current header row come up with better column names and data types for the table schema." \
              "Assume I am using PostgreSQL as the database engine."

    logging.info(f"Prompt: {prompt}")
    body=json.dumps({"Prompt": prompt, table_header: table_header, table_description: table_description})
    #payload.set_body(body)
    payload = func.HttpRequest(method="POST", url="/api/infer_table_schema_using_llm", body=body)
    func.HttpResponse()
    response = infer_table_schema_using_llm(payload, "{}")
    logging.info(f"Response: {response}")
    """
    columns = [Column(field, VARCHAR, primary_key=(field == "playerID")) for field in table_header]
    table = Table(table_name, metadata_obj, *columns, comment=table_description)
    return table

def _get_csv_file(file_name):
    data_df = None
    try:
        logging.info(f"Downloading file name: {file_name} from container {STORAGE_CONTAINER_CSV}")
        container_client = BLOB_SERVICE_CLIENT.get_container_client(STORAGE_CONTAINER_CSV)
        blob_client = container_client.get_blob_client(file_name)
        blob_data = io.BytesIO()
        num_bytes = blob_client.download_blob().readinto(blob_data)
        data_df = pd.read_csv(blob_data)
    except Exception as e:
        logging.error(f"Error getting CSV file: {e}")
    return data_df

@app.orchestration_trigger(context_name="context")
def process_statsbatch(context: df.DurableOrchestrationContext):
    event_json = context.get_input()
    logging.info(f"Received event: {event_json}")
    data_df = _get_csv_file(event_json['file_name'])
    num_batches = int(np.ceil(len(data_df) / BATCH_SIZE))
    logging.info(f"Data has {len(data_df)} rows and will be processed in {num_batches} batches")
    results = []
    for i in range(num_batches):
        logging.info(f"Kicking off batch: {i}")
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
    table_name = eventjson['table_name']
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
    finally:
        await conn.close()
    return True