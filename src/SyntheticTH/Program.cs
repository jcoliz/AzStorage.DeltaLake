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

// Configure Worker options
builder.Services.Configure<WorkerOptions>(
    builder.Configuration.GetSection(WorkerOptions.Section));

// Register EventHubProducerClient as a singleton
// The Event Hubs client types are safe to cache and use as a singleton for the lifetime
// of the application, which is best practice when events are being published or read regularly.
builder.Services.AddSingleton(serviceProvider =>
{
    return new EventHubProducerClient(
        eventHubOptions.ServiceBusEndpoint,
        eventHubOptions.Name,
        new DefaultAzureCredential());
});

builder.Services.AddHostedService<Worker>();

var host = builder.Build();

await host.RunAsync();
