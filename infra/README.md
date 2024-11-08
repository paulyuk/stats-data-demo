Code for azd/Bicep goes here. We need:

Note: we're trying to make this run in Australia East

- VNet and subnets as needed
- Azure Function for upload function (on flex and ACA)
- Azure Function for durable orchestration function (on flex)
- Storage for the above functions
- Azure EventsHub for ingest data to be send to the durable function
- Azure Container App Environment, App and Dynamic Session pool
- Azure OpenAI model for inference
- Inference model (ada atm)
- Azure AI Search with at least 3 partitions