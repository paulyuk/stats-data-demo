import azure.functions as func
import datetime
import json
import logging
import os
import requests
import httpx
import json
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from uuid import uuid16

app = df.DFApp(http_auth_level=func.AuthLevel.ANONYMOUS)


# used to deliver data to the function
EVENTHUB_CONNECTION_STR = os.getenv("EVENTHUB_CONNECTION_STR", None)
EVENTHUB_NAME = os.getenv("EVENTHUB_NAME", None)

# used to create the embedding
EMBEDDING_ENDPOINT = os.getenv("EMBEDDING_ENDPOINT", None)
EMBEDDING_KEY = os.getenv("EMBEDDING_KEY", None)

# used to store embeddings
SEARCH_SERVICE_NAME = "YOUR_SEARCH_SERVICE_NAME"
SEARCH_INDEX_NAME = "YOUR_SEARCH_INDEX_NAME"
SEARCH_API_KEY = "YOUR_SEARCH_API_KEY"

@app.event_hub_message_trigger(arg_name="azeventhub", event_hub_name="eventhubname",
                               connection="EventHubConnectionString") 
def ingest_data(azeventhub: func.EventHubEvent):
    logging.info('Python EventHub trigger processed an event: %s',
                azeventhub.get_body().decode('utf-8'))



@app.event_hub_message_trigger(arg_name="event", 
                               event_hub_name=EVENTHUB_NAME, 
                               connection="EVENTHUB_CONNECTION_STR", 
                               consumer_group="ingester")
@app.durable_client_input(client_name="client")
async def durable_client_trigger(event: func.EventHubEvent, client: df.DurableOrchestrationClient):
    logging.info('EventHub triggered durable function at %s.', datetime.now())
    event_json = json.loads(event.get_body().decode("utf-8"))
    SOMETHING = await client.start_new("process_statsrow", client_input=event_json)
    


@app.orchestration_trigger(context_name="context")
def process_statsrow(context: df.DurableOrchestrationContext):
    event_json = context.get_input()
    logging.info(f"Received event: {event_json}")
    # generate the embedding
    embedding = await embed_statsrow(event_json)
    # store it in azure ai search
    event_json["embedding"] = embedding
    result = await add_document_to_search(event_json)


@app.activity_trigger(input_name="statsrow")
async def embed_statsrow(statsrow: dict):
    logging.info(f"Embedding statsrow: {statsrow}")
    headers = {
        "Content-Type": "application/json",
        "api-key": EMBEDDING_KEY,
    }
    
    logging.info(f"Embedding statsrow: {statsrow}")
    payload = {
        "input": statsrow
    }
    async with httpx.AsyncClient() as client:
        response = await client.post(EMBEDDING_ENDPOINT, headers=headers, json=payload)
        response.raise_for_status()
        embedding = response.json()["data"][0]["embedding"]
        logging.info(f"Embedding: {embedding}")
        return embedding



@app.activity_trigger(input_name="document")
async def add_document_to_search(document: dict):

    search_client = SearchClient(
        endpoint=f"https://{SEARCH_SERVICE_NAME}.search.windows.net",
        index_name=SEARCH_INDEX_NAME,
        credential=AzureKeyCredential(SEARCH_API_KEY)
    )

    document["id"] = str(uuid16())
    logging.info(f"Adding document to search: {document}")
    async with search_client:
        result = await search_client.upload_documents(documents=[document])
        logging.info(f"Upload result: {result}")
        return result
