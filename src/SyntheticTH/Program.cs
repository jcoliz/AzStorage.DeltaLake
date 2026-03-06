using Azure.Core;
using Azure.Identity;
using Azure.Messaging.EventHubs.Producer;
using SyntheticTH;
using SyntheticTH.Options;
using System.IdentityModel.Tokens.Jwt;

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

    // Extract just the hostname from the ServiceBusEndpoint (may be full URL or just hostname)
    var fullyQualifiedNamespace = eventHubOptions.ServiceBusEndpoint;
    if (Uri.TryCreate(eventHubOptions.ServiceBusEndpoint, UriKind.Absolute, out var uri))
    {
        fullyQualifiedNamespace = uri.Host;
    }

    logger
        .LogInformation("Creating EventHubProducerClient with Event Hub Namespace: {Namespace}, Event Hub Name: {EventHubName}",
            fullyQualifiedNamespace, eventHubOptions.Name);

    var credential = GetTokenCredential(identityOptions,logger);
    
    return new EventHubProducerClient(
        fullyQualifiedNamespace,
        eventHubOptions.Name,
        credential);
});

builder.Services.AddHostedService<Worker>();

var host = builder.Build();

await host.RunAsync();

static TokenCredential GetTokenCredential(IdentityOptions identityOptions, ILogger logger)
{
    logger.LogInformation("R5: Determining TokenCredential to use for EventHubProducerClient...");
    
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

    // 2. Check if running in Azure Container Apps (CONTAINER_APP_NAME is set)
    var containerAppName = Environment.GetEnvironmentVariable("CONTAINER_APP_NAME");
    if (!string.IsNullOrEmpty(containerAppName))
    {
        logger.LogInformation("Running in Azure Container Apps ({ContainerApp}), using ManagedIdentityCredential", containerAppName);
        var credential = new ManagedIdentityCredential();
        
        // Diagnostic: Get a token and log its claims to troubleshoot "InvalidIssuer" error
        try
        {
            var tokenContext = new TokenRequestContext(new[] { "https://eventhubs.azure.net/.default" });
            var token = credential.GetToken(tokenContext, default);
            logger.LogInformation("Token acquired successfully. Expires: {ExpiresOn}", token.ExpiresOn);
            
            // Decode the JWT token to see its claims
            var handler = new JwtSecurityTokenHandler();
            var jwtToken = handler.ReadJwtToken(token.Token);
            
            logger.LogInformation("Token Claims:");
            foreach (var claim in jwtToken.Claims)
            {
                logger.LogInformation("  {Type}: {Value}", claim.Type, claim.Value);
            }
            
            // Specifically highlight important claims
            logger.LogInformation("Key Token Details:");
            logger.LogInformation("  Issuer (iss): {Issuer}", jwtToken.Issuer);
            logger.LogInformation("  Audiences (aud): {Audiences}", string.Join(", ", jwtToken.Audiences));
            logger.LogInformation("  Subject (sub): {Subject}", jwtToken.Subject);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error decoding token for diagnostics");
        }
        
        return credential;
    }

    // 3. Use DefaultAzureCredential as a fall-back
    logger.LogInformation("Using DefaultAzureCredential");
    return new DefaultAzureCredential();
}
