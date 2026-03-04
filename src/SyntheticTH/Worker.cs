using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using Microsoft.Extensions.Options;
using System.Text;
using System.Text.Json;
using SyntheticTH.Options;

namespace SyntheticTH;

public partial class Worker(ILogger<Worker> logger, EventHubProducerClient producerClient, IOptions<WorkerOptions> options) : BackgroundService
{
    private readonly Guid sessionId = Guid.NewGuid();
    private int nextMessageSequenceNumber = 1;
    private readonly WorkerOptions _options = options.Value;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        LogWorkerStarted(logger, sessionId);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var messages = GenerateMessages(_options.NumberOfMessages).ToList();
                LogGeneratedMessages(logger, messages.Count, messages.FirstOrDefault());

                await SendMessagesToEventHubAsync(messages, stoppingToken);
                LogBatchPublished(logger, messages.Count, sessionId);
            }
            catch (Exception ex)
            {
                LogErrorGeneratingMessages(logger, ex);
            }

            await Task.Delay(_options.DelayBetweenRuns, stoppingToken);
        }
    }

    private IEnumerable<THMetrics> GenerateMessages(int count)
    {

        for (int i = 1; i <= count; i++)
        {
            yield return new THMetrics
            {
                SequenceNumber = nextMessageSequenceNumber++,
                Temperature = 30.0 + 0.5 * ( nextMessageSequenceNumber % 10),
                Humidity = 60.0 + 0.5 * (nextMessageSequenceNumber % 10),
                TempCorrection = 0.05m * nextMessageSequenceNumber,
                HumidityCorrection = 0.001m * nextMessageSequenceNumber,
                SessionId = sessionId
            };
        }
    }

    private async Task SendMessagesToEventHubAsync(IEnumerable<THMetrics> messages, CancellationToken cancellationToken = default)
    {
        // Create a batch of events
        using EventDataBatch eventBatch = await producerClient.CreateBatchAsync(cancellationToken);

        int eventCount = 0;

        foreach (var message in messages)
        {
            eventCount++;

            var jsonMessage = JsonSerializer.Serialize(message);
            var eventData = new EventData(Encoding.UTF8.GetBytes(jsonMessage));

            if (!eventBatch.TryAdd(eventData))
            {
                // if it is too large for the batch
                throw new Exception($"Event {eventCount} is too large for the batch and cannot be sent.");
            }
        }

        // Use the producer client to send the batch of events to the event hub
        await producerClient.SendAsync(eventBatch, cancellationToken);
    }

    [LoggerMessage(1, LogLevel.Information, "Worker started with session ID: {sessionId}")]
    private static partial void LogWorkerStarted(ILogger logger, Guid sessionId);

    [LoggerMessage(2, LogLevel.Information, "Generated {count} messages. First message: {@message}")]
    private static partial void LogGeneratedMessages(ILogger logger, int count, THMetrics? message);

    [LoggerMessage(3, LogLevel.Error, "Error generating messages")]
    private static partial void LogErrorGeneratingMessages(ILogger logger, Exception ex);

    [LoggerMessage(4, LogLevel.Information, "Worker running at: {time}")]
    private static partial void LogWorkerRunning(ILogger logger, DateTimeOffset time);

    [LoggerMessage(5, LogLevel.Information, "A batch of {count} events has been published for session {sessionId}")]
    private static partial void LogBatchPublished(ILogger logger, int count, Guid sessionId);
}
