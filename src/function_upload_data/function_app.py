import azure.functions as func
import logging
from azure.eventhub import EventHubProducerClient, EventData
import os
import base64
import json
from datetime import datetime, timedelta, timezone
import pandas as pd
import time
import io

# inference
#import aiohttp
import asyncio
import json
import os
import logging


app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

EVENTHUB_CONNECTION_STR = os.getenv("EVENTHUB_CONNECTION")
EVENTHUB_NAME = os.getenv("EVENT_HUB")
BATCH_SIZE = 1000
PRODUCER = EventHubProducerClient.from_connection_string(EVENTHUB_CONNECTION_STR, eventhub_name=EVENTHUB_NAME)


# accept a file and store it in either eventhub or storage
@app.function_name(name="upload_data")
@app.route(route="upload_data", methods=["POST"])
#@app.event_hub_output(arg_name="outevent", 
#                      event_hub_name=EVENTHUB_NAME, 
#                      connection="EVENTHUB_CONNECTION_STR")

#def upload_data(req: func.HttpRequest, outevent: func.Out[str]) -> func.HttpResponse:
def upload_data(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Extract input data from the request
        file_data = req.files.get('file_data')
        file_name = req.form.get('file_name')
        logging.info(f"Received file: {file_name}.")

        if not file_data or not file_name:
            return func.HttpResponse("Missing file_data or file_name in the request.\n", status_code=400)

        # Read binary data from the file_data object
        csv_data = io.BytesIO(file_data.read())
        csv_df = pd.read_csv(csv_data)
        header = csv_df.columns.tolist()
        messages = []
        # Convert the binary data to a pandas DataFrame
        batch_counter = 0
        batch = PRODUCER.create_batch()
        
        for index, row in csv_df.iterrows():
            message = {
                "file_name": file_name,
                "timestamp": datetime.now().isoformat(),
                "data": row.to_dict()
            }
            message_str = json.dumps(message)
            batch.add(EventData(message_str))
            if len(batch) >= BATCH_SIZE:
                PRODUCER.send_batch(batch)
                batch = PRODUCER.create_batch()
                batch_counter += 1
                logging.info(f"Sent batch {batch_counter} to Event Hub.")
        if len(batch) > 0:
            PRODUCER.send_batch(batch)
            batch_counter += 1
            logging.info(f"Sent batch {batch_counter} to Event Hub.")


        return func.HttpResponse(f"File {file_name} processed and added to the queue.\n", status_code=200)

    except Exception as e:
        logging.error(f"Error processing request: {e}")
        return func.HttpResponse("Error processing request.\n", status_code=500)
