public record Message
{
    public DateTimeOffset TimeGenerated { get; init; } = DateTimeOffset.UtcNow;
    public int SequenceNumber { get; init; }
    public string Model { get; init; } = string.Empty;
    public Metrics Metrics { get; init; } = new();
    public Guid SessionId { get; init; } = Guid.Empty;
}

public record Metrics
{
    public double Temperature { get; init; }
    public double Humidity { get; init; }
    public double TempCorrection { get; init; }
    public double HumidityCorrection { get; init; }
}