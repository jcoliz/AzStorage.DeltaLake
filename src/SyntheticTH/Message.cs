using Microsoft.Azure.Amqp.Sasl;

namespace SyntheticTH;

public record THMessage
{
    public DateTimeOffset TimeGenerated { get; init; } = DateTimeOffset.UtcNow;
    public int SequenceNumber { get; init; }
    public string Model { get; init; } = "dtmi:reference:sensors:TH;1";
    public Guid SessionId { get; init; } = Guid.Empty;
    public string Source { get; init; } = "device1/th1";
}

// NOTE: We are flattening this here for simplicity, but in a real-world scenario you may want to have a more complex object graph
// with a THMessage containing a THMetrics object. The downstream processing would handle flattening as needed for storage in Delta Lake or other sinks.

public record THMetrics: THMessage
{
    public double Temperature { get; init; }
    public double Humidity { get; init; }
    public decimal TempCorrection { get; init; }
    public decimal HumidityCorrection { get; init; }
}