using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;

namespace AgentBridgeFunction;

public interface IAlertEventPublisher
{
    Task PublishAsync(string payload, string correlationId, CancellationToken cancellationToken);
}

public sealed class EventHubAlertPublisher : IAlertEventPublisher, IAsyncDisposable
{
    private readonly EventHubProducerClient _producer;
    public EventHubAlertPublisher(EventHubProducerClient producer) => _producer = producer;

    public Task PublishAsync(string payload, string correlationId, CancellationToken cancellationToken)
    {
        var eventData = new EventData(BinaryData.FromString(payload)) { ContentType = "application/json" };
        eventData.Properties["source"] = "kibana";
        eventData.Properties["correlationId"] = correlationId;
        return _producer.SendAsync(new[] { eventData }, cancellationToken);
    }

    public ValueTask DisposeAsync() => _producer.DisposeAsync();
}
