using Azure.Core;
using Azure.Identity;
using Azure.Messaging.EventHubs.Producer;
using SyntheticTH;
using SyntheticTH.Options;

var builder = Host.CreateApplicationBuilder(args);

// Load configuration from optional config.toml
builder.Configuration.AddTomlFile("config.toml", optional: true);

// Bind EventHub configuration
var eventHubOptions = new EventHubOptions();
builder.Configuration.Bind(EventHubOptions.Section, eventHubOptions);

// Bind Identity configuration
var identityOptions = new IdentityOptions();
builder.Configuration.Bind(IdentityOptions.Section, identityOptions);

// Configure Worker options
builder.Services.Configure<WorkerOptions>(
    builder.Configuration.GetSection(WorkerOptions.Section));

// Register EventHubProducerClient as a singleton
// The Event Hubs client types are safe to cache and use as a singleton for the lifetime
// of the application, which is best practice when events are being published or read regularly.
builder.Services.AddSingleton(serviceProvider =>
{
    var logger = serviceProvider.GetRequiredService<ILogger<Program>>();

    logger
        .LogInformation("Creating EventHubProducerClient with Event Hub Namespace: {Namespace}, Event Hub Name: {EventHubName}",
            eventHubOptions.ServiceBusEndpoint, eventHubOptions.Name);

    var credential = GetTokenCredential(identityOptions,logger);
    
    return new EventHubProducerClient(
        eventHubOptions.ServiceBusEndpoint,
        eventHubOptions.Name,
        credential);
});

builder.Services.AddHostedService<Worker>();

var host = builder.Build();

await host.RunAsync();

static TokenCredential GetTokenCredential(IdentityOptions identityOptions, ILogger logger)
{
    // 1. If there is an IdentityOptions filled out, create a ClientSecretCredential and use that
    if (identityOptions.TenantId != Guid.Empty &&
        identityOptions.AppId != Guid.Empty &&
        !string.IsNullOrWhiteSpace(identityOptions.AppSecret))
    {
        logger.LogInformation("Using ClientSecretCredential with TenantId: {TenantId}, AppId: {AppId}",
            identityOptions.TenantId, identityOptions.AppId);

        return new ClientSecretCredential(
            identityOptions.TenantId.ToString(),
            identityOptions.AppId.ToString(),
            identityOptions.AppSecret);
    }

    // 2. If a Managed Identity credential is available, use that
    try
    {
        var managedIdentityCredential = new ManagedIdentityCredential();
        // Test if managed identity is available by attempting to get a token
        // This will throw if managed identity is not available
        var tokenRequestContext = new TokenRequestContext(new[] { "https://eventhubs.azure.net/.default" });
        var token = managedIdentityCredential.GetToken(tokenRequestContext, default);
        logger.LogInformation("Using ManagedIdentityCredential, token expires on: {ExpiresOn}", token.ExpiresOn);
        return managedIdentityCredential;
    }
    catch
    {
        // Managed identity not available, fall through to default
    }

    // 3. Use DefaultAzureCredential as a fall-back
    logger.LogInformation("Using DefaultAzureCredential");
    return new DefaultAzureCredential();
}
