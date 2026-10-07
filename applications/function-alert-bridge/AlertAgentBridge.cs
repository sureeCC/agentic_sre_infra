using Azure.Messaging.EventHubs;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace AgentBridgeFunction;

public sealed class AlertAgentBridge
{
    private const string RequiredKibanaRole = "Kibana.Alert.Send";
    private readonly ILogger<AlertAgentBridge> _logger;
    private readonly IAlertEventPublisher _eventPublisher;
    private readonly IFoundryAgentDispatcher _agentDispatcher;

    public AlertAgentBridge(ILogger<AlertAgentBridge> logger, IAlertEventPublisher eventPublisher, IFoundryAgentDispatcher agentDispatcher)
        => (_logger, _eventPublisher, _agentDispatcher) = (logger, eventPublisher, agentDispatcher);

    [Function("ReceiveKibanaAlert")]
    public async Task<IActionResult> ReceiveKibanaAlert([HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "alerts/kibana")] HttpRequest request, CancellationToken cancellationToken)
    {
        var authorization = ClientPrincipalRoleValidator.Authorize(request, RequiredKibanaRole);
        if (authorization == ClientPrincipalAuthorization.NoPrincipal) return new UnauthorizedObjectResult("Authentication is required.");
        if (authorization != ClientPrincipalAuthorization.Allowed) return new ForbidResult();

        var correlationId = CorrelationId.Create(request.Headers["x-correlation-id"]);
        using var scope = _logger.BeginScope(new Dictionary<string, object> { ["CorrelationId"] = correlationId });
        var payload = await AlertPayloadReader.ReadAndValidateAsync(request, cancellationToken);
        if (!payload.IsValid) return new BadRequestObjectResult(payload.Error);

        try
        {
            await _eventPublisher.PublishAsync(payload.Value!, correlationId, cancellationToken);
            return new ObjectResult(new { status = "accepted", correlationId, acceptedAtUtc = DateTimeOffset.UtcNow }) { StatusCode = StatusCodes.Status202Accepted };
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { return new StatusCodeResult(StatusCodes.Status499ClientClosedRequest); }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unable to queue Kibana alert to Event Hubs.");
            return new ObjectResult("The alert could not be queued.") { StatusCode = StatusCodes.Status503ServiceUnavailable };
        }
    }

    [Function("ProcessEventHubAlert")]
    public async Task ProcessEventHubAlert([EventHubTrigger("%EVENTHUB_NAME%", ConsumerGroup = "%EVENTHUB_CONSUMER_GROUP%", Connection = "EventHubConnection")] EventData[] events, CancellationToken cancellationToken)
    {
        foreach (var eventData in events)
        {
            var correlationId = eventData.Properties.TryGetValue("correlationId", out var value) && value is string candidate ? CorrelationId.Create(candidate) : Guid.NewGuid().ToString("N");
            var payload = AlertPayloadValidator.Validate(eventData.EventBody.ToString());
            if (!payload.IsValid) { _logger.LogWarning("Skipping malformed Event Hubs alert: {ValidationError}", payload.Error); continue; }
            try { await _agentDispatcher.DispatchAsync(payload.Value!, correlationId, cancellationToken); }
            catch (Exception ex) when (ex is not OperationCanceledException || !cancellationToken.IsCancellationRequested)
            {
                _logger.LogError(ex, "Foundry Hosted Agent dispatch failed; Event Hubs retry will be requested.");
                throw;
            }
        }
    }
}
