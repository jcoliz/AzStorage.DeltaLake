namespace SyntheticTH.Options;

public class WorkerOptions
{
    public static readonly string Section = "Worker";

    public int NumberOfMessages { get; set; } = 3;
    public TimeSpan DelayBetweenRuns { get; set; } = TimeSpan.FromMinutes(5);
}
