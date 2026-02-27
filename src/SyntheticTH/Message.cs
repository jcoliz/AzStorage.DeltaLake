namespace SyntheticTH;

public record THMessage
{
    public DateTimeOffset TimeGenerated { get; init; } = DateTimeOffset.UtcNow;
    public int SequenceNumber { get; init; }
    public string Model { get; init; } = "dtmi:synthetic:sensors:TH;1";
    public THMetrics Metrics { get; init; } = new();
    public Guid SessionId { get; init; } = Guid.Empty;
}

public record THMetrics
{
    public double Temperature { get; init; }
    public double Humidity { get; init; }
    public double TempCorrection { get; init; }
    public double HumidityCorrection { get; init; }
}