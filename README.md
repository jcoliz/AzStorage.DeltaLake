# Azure Data Lake Storage Gen2 with Delta Lake

A complete end-to-end solution demonstrating how to stream IoT telemetry data from Azure Event Hubs through Azure Stream Analytics into an Azure Data Lake Storage Gen2 account, with output stored in Delta Lake format.

![Archiecture](./docs/images/AzStororage.DetlaLake%20Architecture.png)

## Overview

This project showcases a production-ready data ingestion pipeline that:

- **Generates** synthetic IoT sensor data (temperature and humidity)
- **Streams** data through Azure Event Hubs
- **Processes** data in real-time using Azure Stream Analytics
- **Stores** data in Delta Lake format on Azure Data Lake Storage Gen2
- **Enables** downstream consumption using specified Service Principal
- **Uses** passwordless authentication throughout (Managed Identities and Service Principals with RBAC)

## Components

### SyntheticTH Worker Service

A .NET background service that generates synthetic temperature and humidity sensor data and publishes it to Azure Event Hubs.

**Key Features:**
- Configurable message generation (count and frequency)
- Session-based tracking with unique IDs
- Multiple authentication methods (ClientSecret, ManagedIdentity, DefaultAzureCredential)
- Structured logging for observability

📖 **Documentation:** [`src/SyntheticTH/README.md`](src/SyntheticTH/README.md)

### Infrastructure

Complete Azure infrastructure provisioned via Bicep templates.

**Resources Created:**
- App Registration & Service Principal (for data sender authentication)
- Azure Event Hub Namespace and Hub
- Azure Storage Account (ADLS Gen2 with hierarchical namespace)
- User-Assigned Managed Identity (for Stream Analytics)
- Azure Stream Analytics Job (with Delta Lake output)

📖 **Documentation:** [`infra/README.md`](infra/README.md)

## Getting Started

### Prerequisites

- [Azure Subscription](https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account). Create a free account to get started!
- [Azure CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#azure-cli) with Bicep extensions enabled
- [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) (for deployment scripts)
- [.NET 10.0 SDK](https://dotnet.microsoft.com/download) or later for development

### Quick Start

#### 1. Provision Azure Infrastructure

```powershell
cd infra
./Provision-Resources.ps1
```

This script will:
- Deploy all required Azure resources
- Configure RBAC permissions
- Start an Azure Container Apps worker service which will immediately begin pushing data through the system
- Output configuration values for local development

**Note:** Save the output configuration values—you'll need them for the next step, if you also plan to run the code locally.

#### 2. Configure the Application for Local Development

If you want to run the producer app locally, you'll want to set needed configuration
parameters. Create a `config.toml` file in the `src/SyntheticTH/` directory. You can
use the provided template as an example. These values are provided as outputs of the
Provision-Resources script.

```toml
[EventHub]
Namespace = "ehns-xxxxx"          # From deployment output
Name = "ehub-xxxxx"                # From deployment output
ServiceBusEndpoint = "https://ehns-xxxxx.servicebus.windows.net/"
```

For local development, that's all you need, because it use your Azure CLI credentials.
The deployment script provisions a role assignment for the signed in user to write
data to the Event Hub.

For Docker deployments, you'll also need the `[Identity]` section. Generate it with:

```powershell
cd infra
./Create-AppSecret.ps1 -AppId <senderAppId-from-output>
```

#### 3. Run the Application Locally

```bash
cd src/SyntheticTH
dotnet run
```

The worker will start generating and sending synthetic sensor data to your Event Hub.

#### 4. Verify Data Flow

After a few minutes, check your Azure Storage Account:

1. Navigate to your Storage Account in the Azure Portal
2. Go to **Containers** → **silver** → **metrics3**
3. You should see Delta Lake files (Parquet format with transaction log)

## Related Resources

- [Azure Event Hubs Documentation](https://learn.microsoft.com/azure/event-hubs/)
- [Azure Stream Analytics Documentation](https://learn.microsoft.com/azure/stream-analytics/)
- [Delta Lake Documentation](https://delta.io/)
- [Azure Data Lake Storage Gen2](https://learn.microsoft.com/azure/storage/blobs/data-lake-storage-introduction)
- [Azure Managed Identities](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
