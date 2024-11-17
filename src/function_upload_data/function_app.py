import os
import json
import logging
import io
import pandas as pd
from azure.identity.aio import DefaultAzureCredential, ManagedIdentityCredential
from datetime import datetime, timedelta, timezone
import azure.functions as func
from azure.storage.blob.aio import BlobServiceClient

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)
STORAGE_CONTAINER_CSV = os.getenv("STORAGE_CONTAINER_CSV")
default_credential = DefaultAzureCredential(managed_identity_client_id=os.getenv('AZURE_CLIENT_ID'))
account_url = f"https://{os.getenv('AzureWebJobsStorage__accountName')}.blob.core.windows.net"
blob_service_client = BlobServiceClient(account_url, credential=default_credential)
container_client = blob_service_client.get_container_client(STORAGE_CONTAINER_CSV)

# accept a file, store it in blob storage, and send a message to service bus about the file with extra metadata and context
#TODO make this async
@app.function_name(name="upload_data")
@app.route(route="upload_data", methods=[func.HttpMethod.POST])
@app.service_bus_queue_output(arg_name="message",
                              connection="SERVICEBUS_CONNECTION",
                              queue_name="%FULL_FILE_SERVICEBUS_QUEUE_NAME%")
async def upload_data(req: func.HttpRequest, message: func.Out[str]) -> func.HttpResponse:
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

        file_url = await _upload_to_blob(binary_filedata, file_name)

        messagejson = {
            "file_name": file_name,
            "table_name": file_name.replace(".", "_").lower(),
            "timestamp": datetime.now().isoformat(),
            "header": header,
            "file_description": file_description,
            "file_url": file_url
        }
        message.set(json.dumps(messagejson))

        return func.HttpResponse(f"File {file_name} processed and added to the queue.\n", status_code=200)

    except Exception as e:
        logging.error(f"Error processing request: {e}")
        return func.HttpResponse(f"Error processing request. {e} \n", status_code=500)

# accept a file with just header and first line and send a message to service bus about the file with extra metadata, context, and content 
#TODO make this async
@app.function_name(name="upload_data_single")
@app.route(route="upload_data_single", methods=[func.HttpMethod.POST])
@app.service_bus_queue_output(arg_name="message",
                              connection="SERVICEBUS_CONNECTION",
                              queue_name="%SINGLE_LINE_SERVICEBUS_QUEUE_NAME%")
async def upload_data_single(req: func.HttpRequest, message: func.Out[str]) -> func.HttpResponse:
    try:
        # Extract input data from the request
        logging.info(f"Executing upload_data_single.")

        message.set(req.get_body().decode('utf-8'))

        return func.HttpResponse(f"upload_data_single processed and added to the queue.\n", status_code=200)

    except Exception as e:
        logging.error(f"Error processing request: {e}")
        return func.HttpResponse(f"Error processing request. {e} \n", status_code=500)


#TODO make this async
async def _upload_to_blob(file_data, file_name):
    try:
        blob_client = container_client.get_blob_client(file_name)
        await blob_client.upload_blob(file_data, overwrite=True)
        return blob_client.url
    except Exception as e:
        logging.error(f"Error uploading file {file_name} to Azure Blob Storage: {e}")
        raise