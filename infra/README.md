Code for azd/Bicep goes here. We need:

Note: we're trying to make this run in Australia East

- User assigned managed identity
- VNet and subnets as needed
- Private endpoints for everything below
- Azure Function for upload function (on flex and ACA)
- Azure Function for durable orchestration function (on flex)
- Storage for the above functions
- Azure Service Bus for ingest data to be send to the durable function (used to be EventsHub)
- Azure Container App Environment, Apps and 
- Dynamic Session pool
- Azure OpenAI model for inference (gpt-4o-mini) and embeddings (text-embedding-ada-002)
- PostgreSQL DB (ideally premium)