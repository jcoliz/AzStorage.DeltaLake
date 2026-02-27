namespace SyntheticTH.Options;

public class EventHubOptions
{
    public static readonly string Section = "EventHub";

    public string Namespace { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string ServiceBusEndpoint { get; set; } = string.Empty;
}
