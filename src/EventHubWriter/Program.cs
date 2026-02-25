
// https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-dotnet-standard-getstarted-send?tabs=passwordless%2Croles-azure-portal

using Azure.Identity;
using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using Microsoft.Extensions.Configuration;
using System.Text;
using System.Text.Json;

// number of events to be sent to the event hub
const int numOfEvents = 3;

//
// Load configuration
//

var configuration = new ConfigurationBuilder()
    .AddTomlFile("config.toml", optional: true)
    .Build();

var eventHubOptions = new EventHubOptions();
configuration.Bind(EventHubOptions.Section, eventHubOptions);

// The Event Hubs client types are safe to cache and use as a singleton for the lifetime
// of the application, which is best practice when events are being published or read regularly.
EventHubProducerClient producerClient = new EventHubProducerClient(
    eventHubOptions.ServiceBusEndpoint,
    eventHubOptions.Name,
    new DefaultAzureCredential());

// Id for this session
var sessionId = Guid.NewGuid();

// Create a batch of events 
using EventDataBatch eventBatch = await producerClient.CreateBatchAsync();

for (int i = 1; i <= numOfEvents; i++)
{
    var message = new Message
    {
        SequenceNumber = i,
        Model = "dtmi:brewhub:sensors:TH;1",
        Metrics = new Metrics
        {
            Temperature = 30 + i,
            Humidity = 60 + i,
            TempCorrection = 0.05 * i,
            HumidityCorrection = 0.001 * i
        },
        SessionId = sessionId
    };

    if (!eventBatch.TryAdd(new EventData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message)))))
    {
        // if it is too large for the batch
        throw new Exception($"Event {i} is too large for the batch and cannot be sent.");
    }
}

try
{
    // Use the producer client to send the batch of events to the event hub
    await producerClient.SendAsync(eventBatch);
    Console.WriteLine($"A batch of {numOfEvents} events has been published for session {sessionId}.");
}
finally
{
    await producerClient.DisposeAsync();
}