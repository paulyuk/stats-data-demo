Todo:

* Fill out this readme - example https://github.com/Azure-Samples/functions-e2e-http-to-eventhubs
* Ensure managed identity is being used by all function apps for all services (upload data seems to expect a connection string to event hubs currently)
* Change the managed identity used for the functions apps to user assigned, one per app (they're currently service assigned)
* Add the orchestration code to the orchestrator
* Finalize the code for the upload data function
* add a .http file to help uploading the files for testing - example https://github.com/microsoft/hands-on-lab-azure-functions-flex-openai/blob/main/audioupload.http
* Add ACA GPU, Video Memory AI Search/Open AI, Endpoint for user interaction