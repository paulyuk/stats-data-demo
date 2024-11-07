import azure.functions as func
import logging
from azure.eventhub import EventHubProducerClient, EventData
import os
import base64
import json
from datetime import datetime, timedelta, timezone
import pandas as pd
import time
import uuid

# inference
#import aiohttp
import asyncio
import json
import os
import logging
from azure.storage.blob import BlobServiceClient, BlobSasPermissions, generate_blob_sas

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

EVENTHUB_CONNECTION_STR = os.getenv("EVENTHUB_CONNECTION_STR")
EVENTHUB_NAME = os.getenv("EVENTHUB_NAME_INGEST")



# accept a file and store it in either eventhub or storage
@app.function_name(name="upload_data")
@app.route(route="upload_data", methods=["POST"])
@app.event_hub_output(arg_name="outevent", 
                      event_hub_name=EVENTHUB_NAME, 
                      connection="EVENTHUB_CONNECTION_STR")

def upload_data(req: func.HttpRequest, outevent: func.Out[str]) -> func.HttpResponse:
    global STORAGE_CONNECTION_STR, STORAGE_CONTAINER_NAME
    logging.info('HTTP trigger function received a request.')

    try:
        # Extract input data from the request
        file_data = req.files.get('file_data')
        file_name = req.form.get('file_name')
        logging.info(f"Received file: {file_name}.")

        if not file_data or not file_name:
            return func.HttpResponse("Missing file_data or file_name in the request.\n", status_code=400)

        # Read binary data from the file_data object
        csv_data = file_data.read()

        # Convert the binary data to a pandas DataFrame
        for index, row in pd.read_csv(csv_data).iterrows():
            message = {
                "file_name": file_name,
                "timestamp": datetime.now().isoformat(),
                "header": header,
                "data": row.to_dict()
            }
            message_str = json.dumps(message)
            outevent.set(message_str)


        return func.HttpResponse(f"File {file_name} processed and added to the queue.\n", status_code=200)

    except Exception as e:
        logging.error(f"Error processing request: {e}")
        return func.HttpResponse("Error processing request.\n", status_code=500)
    


