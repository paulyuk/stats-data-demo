import os
import json
import logging
import io
import pandas as pd
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
from datetime import datetime, timedelta, timezone
import azure.functions as func
from azure.storage.blob import BlobServiceClient
from azure.servicebus import ServiceBusClient
from azure.servicebus import ServiceBusMessage

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)
STORAGE_CONTAINER_CSV = os.getenv("STORAGE_CONTAINER_CSV")
SINGLE_LINE_SERVICEBUS_QUEUE_NAME = os.getenv("SINGLE_LINE_SERVICEBUS_QUEUE_NAME")
FULL_FILE_SERVICEBUS_QUEUE_NAME = os.getenv("FULL_FILE_SERVICEBUS_QUEUE_NAME")
default_credential = DefaultAzureCredential(managed_identity_client_id=os.getenv('AZURE_CLIENT_ID'))

# accept a file, store it in blob storage, and send a message to service bus about the file with extra metadata and context
#TODO make this async
@app.function_name(name="upload_data")
@app.route(route="upload_data", methods=[func.HttpMethod.POST])
def upload_data(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Extract input data from the request
        file_data = req.files.get('file_data')
        file_name = req.form.get('file_name')
        file_description = req.form.get('file_description')
        logging.info(f"Received file: {file_name}.")

        if not file_data or not file_name:
            return func.HttpResponse("Missing file_data or file_name in the request.\n", status_code=400)

        # Read binary data from the file_data object
        binary_filedata = file_data.read()
        csv_data = io.BytesIO(binary_filedata)
        csv_df = pd.read_csv(csv_data, nrows=2)
        header = [h.lower() for h in csv_df.columns.tolist()]

        file_url = _upload_to_blob(binary_filedata, file_name)

        message = {
            "file_name": file_name,
            "table_name": file_name.replace(".", "_").lower(),
            "timestamp": datetime.now().isoformat(),
            "header": header,
            "file_description": file_description,
            "file_url": file_url
        }
        message_str = json.dumps(message)
        _send_to_servicebus(message_str, FULL_FILE_SERVICEBUS_QUEUE_NAME)

        return func.HttpResponse(f"File {file_name} processed and added to the queue.\n", status_code=200)

    except Exception as e:
        logging.error(f"Error processing request: {e}")
        return func.HttpResponse("Error processing request.\n", status_code=500)

# accept a file with just header and first line and send a message to service bus about the file with extra metadata, context, and content 
#TODO make this async
@app.function_name(name="upload_data_single")
@app.route(route="upload_data_single", methods=[func.HttpMethod.POST])
def upload_data_single(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Extract input data from the request
        file_data = req.files.get('file_data')
        file_name = req.form.get('file_name')
        file_description = req.form.get('file_description')
        logging.info(f"Received file: {file_name}.")

        if not file_data or not file_name:
            return func.HttpResponse("Missing file_data or file_name in the request.\n", status_code=400)

        # Read binary data from the file_data object
        binary_filedata = file_data.read()
        csv_data = io.BytesIO(binary_filedata)
        csv_df = pd.read_csv(csv_data, nrows=2)
        header = [h.lower() for h in csv_df.columns.tolist()]

        message = {
            "file_name": file_name,
            "table_name": file_name.replace(".", "_").lower(),
            "timestamp": datetime.now().isoformat(),
            "header": header,
            "file_description": file_description
            #TODO add rest of file content?
        }
        message_str = json.dumps(message)
        _send_to_servicebus(message_str, SINGLE_LINE_SERVICEBUS_QUEUE_NAME)

        return func.HttpResponse(f"File {file_name} processed and added to the queue.\n", status_code=200)

    except Exception as e:
        logging.error(f"Error processing request: {e}")
        return func.HttpResponse("Error processing request.\n", status_code=500)


#TODO make this async
def _upload_to_blob(file_data, file_name):
    account_url = f"https://{os.getenv('AzureWebJobsStorage__accountName')}.blob.core.windows.net"
    blob_service_client = BlobServiceClient(account_url, credential=default_credential)
    container_client = blob_service_client.get_container_client(STORAGE_CONTAINER_CSV)
    try:
        blob_client = container_client.get_blob_client(file_name)
        blob_client.upload_blob(file_data, overwrite=True)
        return blob_client.url
    except Exception as e:
        logging.error(f"Error uploading file {file_name} to Azure Blob Storage: {e}")
        raise

#TODO make this async
def _send_to_servicebus(message, queue_name):
    servicebus_fqdn = os.getenv('SERVICEBUS_CONNECTION__fullyQualifiedNamespace')
    servicebus_client = ServiceBusClient(servicebus_fqdn, credential=default_credential)
    try:
        sender = servicebus_client.get_queue_sender(queue_name=queue_name)
        message = ServiceBusMessage(message)
        sender.send_messages(message)
    except Exception as e:
        logging.error(f"Error sending service bus message to Azure Service Bus: {e}")
        raise