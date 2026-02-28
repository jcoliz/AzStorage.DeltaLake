# SyntheticTH - Synthetic Temperature & Humidity Data Generator

A .NET worker service that generates synthetic temperature and humidity sensor data and sends it to Azure Event Hubs. This application simulates IoT device telemetry for testing data ingestion pipelines.

## Overview

SyntheticTH is designed to:
- Generate predictable synthetic sensor readings (temperature and humidity)
- Send data in batches to Azure Event Hubs
- Run as a background worker service
- Support multiple deployment scenarios (local, Docker, Azure Container Apps)

Each message includes temperature, humidity, and correction factors, along with a session ID for tracking batches.

## Message Format

The application sends JSON messages in the following format:

```json
{
  "TimeGenerated": "2026-02-28T01:23:45.678Z",
  "SequenceNumber": 1,
  "Model": "dtmi:synthetic:sensors:TH;1",
  "Metrics": {
    "Temperature": 31.0,
    "Humidity": 61.0,
    "TempCorrection": 0.05,
    "HumidityCorrection": 0.001
  },
  "SessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

### Message Properties

- **TimeGenerated**: UTC timestamp when the message was created
- **SequenceNumber**: Incremental number within the session
- **Model**: DTMI identifier for the synthetic sensor model
- **Metrics**: Sensor readings
  - **Temperature**: Current temperature
  - **Humidity**: Current humidity
  - **TempCorrection**: Correction value applied on sensor
  - **HumidityCorrection**: Correction value applied on sensor
- **SessionId**: Unique GUID per worker session

## Configuration

The application is configured through a `config.toml` file. See [`config-template.toml`](config-template.toml:1) for the full template.

### Required Configuration

#### EventHub Section

```toml
[EventHub]
Namespace = "ehns-xxxxx"
Name = "ehub-xxxxx"
ServiceBusEndpoint = "https://ehns-xxxxx.servicebus.windows.net/"
```

These values are provided by the infrastructure deployment. See [Infrastructure Documentation](../../infra/README.md:1) for details.

### Optional Configuration

#### Worker Section

```toml
[Worker]
NumberOfMessages = 3           # Number of messages per batch
DelayBetweenRuns = "00:05:00" # Delay between batches (HH:MM:SS format)
```

Defaults: 3 messages per batch, 5-minute delay between runs.

#### Identity Section

```toml
[Identity]
TenantId = "your-tenant-id"
AppId = "your-app-id"
AppSecret = "your-client-secret"
```

**Required for**: Docker containers and Azure Container Apps deployments
**Optional for**: Local development (otherwise will use DefaultAzureCredential)

## Authentication

The application supports multiple authentication methods, attempted in this order:

1. **Client Secret Credential**: If `[Identity]` section is fully configured with TenantId, AppId, and AppSecret
2. **Managed Identity**: If running in Azure with managed identity enabled (Azure Container Apps)
3. **Default Azure Credential**: Falls back to local development credentials (Azure CLI, Visual Studio, etc.)

For local development without the `[Identity]` section, ensure you have appropriate Event Hub permissions (Data Sender role) via your Azure account. This is provisioned automatically if you've
used the `Provision-Resources.ps1` script.

## Running Locally

### Prerequisites

- .NET 10.0 SDK or later
- Azure Event Hub provisioned (see [Infrastructure](../../infra/README.md:1))
- Azure CLI authenticated (`az login`)

### Steps

1. Create a `config.toml` file in this directory with Event Hub configuration:

```bash
cp config-template.toml config.toml
# Edit config.toml with your Event Hub details
```

2. Run the application:

```bash
dotnet run
```

The worker will generate and send batches of messages according to the configured schedule.

## Running in Docker

### Build the Docker Image

Use the provided build script from the repository root:

```bash
./scripts/Build-Containers.ps1
```

### Run the Container

1. Create a [`config.toml`](../../docker/config.toml:1) file in the `docker/` directory with Event Hub and Identity configuration
2. Run the container using the provided script:

```bash
./scripts/Start-Containers.ps1
```

## Deployment to Azure Container Apps

This application is designed to run in Azure Container Apps with Managed Identity authentication.

### Container App Configuration

When deploying to Azure Container Apps:

1. Enable **System-assigned Managed Identity** on the Container App
2. Grant the managed identity **Azure Event Hubs Data Sender** role on the Event Hub
3. Provide environment variables or mount a `config.toml` with Event Hub configuration (Identity section not needed)

The application will automatically use the managed identity for authentication.

## Project Structure

- [`Worker.cs`](Worker.cs:1) - Background service that generates and sends messages
- [`Message.cs`](Message.cs:1) - Message data models (THMessage, THMetrics)
- [`Program.cs`](Program.cs:1) - Application startup and dependency injection configuration
- **Options/** - Configuration option classes
  - [`EventHubOptions.cs`](Options/EventHubOptions.cs:1) - Event Hub connection settings
  - [`IdentityOptions.cs`](Options/IdentityOptions.cs:1) - Service principal authentication settings
  - [`WorkerOptions.cs`](Options/WorkerOptions.cs:1) - Worker behavior settings

## Logging

The application uses structured logging with the following key events:

- Worker startup with session ID
- Message generation details (count and first message preview)
- Batch publication confirmation
- Error details for troubleshooting

Logs are written to console and can be collected by container logging systems.

## Dependencies

- **Azure.Messaging.EventHubs** - Event Hub client library
- **Azure.Identity** - Azure authentication
- **Microsoft.Extensions.Hosting** - Background worker service framework
- **Tomlyn** - TOML configuration file support (via AddTomlFile extension)

## Related Documentation

- [Infrastructure Setup](../../infra/README.md:1) - How to provision Azure resources
- [Docker Configuration](../../docker/) - Container deployment instructions
- [Build Scripts](../../scripts/) - Build and deployment automation
