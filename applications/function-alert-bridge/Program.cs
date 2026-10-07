using AgentBridgeFunction;
using Azure.Core;
using Azure.Identity;
using Azure.Messaging.EventHubs.Producer;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = FunctionsApplication.CreateBuilder(args);
builder.ConfigureFunctionsWebApplication();

builder.Services.AddSingleton<TokenCredential, DefaultAzureCredential>();
builder.Services.AddSingleton<IAlertEventPublisher>(services =>
{
    var configuration = services.GetRequiredService<IConfiguration>();
    var credential = services.GetRequiredService<TokenCredential>();
    var fullyQualifiedNamespace = configuration["EVENTHUB_FULLY_QUALIFIED_NAMESPACE"]
        ?? throw new InvalidOperationException("App setting EVENTHUB_FULLY_QUALIFIED_NAMESPACE is required.");
    var eventHubName = configuration["EVENTHUB_NAME"]
        ?? throw new InvalidOperationException("App setting EVENTHUB_NAME is required.");

    return new EventHubAlertPublisher(new EventHubProducerClient(
        fullyQualifiedNamespace,
        eventHubName,
        credential,
        new EventHubProducerClientOptions()));
});
builder.Services.AddHttpClient<IFoundryAgentDispatcher, FoundryAgentDispatcher>(client =>
{
    client.Timeout = TimeSpan.FromSeconds(60);
    client.DefaultRequestHeaders.UserAgent.ParseAdd("agentic-sre-alert-bridge/1.0");
});

builder.Build().Run();
