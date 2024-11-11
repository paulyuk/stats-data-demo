Todo:

* Fill out this readme - example https://github.com/Azure-Samples/functions-e2e-http-to-eventhubs
* Ensure managed identity is being used by all function apps for all services (upload data seems to expect a connection string to event hubs currently)
* Change the managed identity used for the functions apps to user assigned, one per app (they're currently service assigned)
* Add the orchestration code to the orchestrator
* Finalize the code for the upload data function
* add a .http file to help uploading the files for testing - example https://github.com/microsoft/hands-on-lab-azure-functions-flex-openai/blob/main/audioupload.http
* Add ACA GPU, Video Memory AI Search/Open AI, Endpoint for user interaction


## Basic Testing Steps

After standing up the functions (upload and orchestrate) you can upload data via the following sample commands:

```bash
# define the endpoints for both upload function (assuming localhost here)
export UPLOAD_ENDPOINT=http://localhost:7071


# navigate to the data directory
cd ./data/baseball_databank

# first, let's import the master csv
curl -X POST "${UPLOAD_ENDPOINT}/api/upload_data" \
     -F "file_data=@test_Master.csv" \
     -F "file_name=test_Master.csv" \
     -F "file_description=A table with information about baseball players. The primary key is playerid."

# import batting stats
curl -X POST "${UPLOAD_ENDPOINT}/api/upload_data" \
     -F "file_data=@test_Batting.csv" \
     -F "file_name=test_Batting.csv" \
     -F "file_description=A table with information about baseball batting statistics. The primary key is playerid."
```

Once the data is imported run the /src/app_text2sql/simple_text2sql.py.