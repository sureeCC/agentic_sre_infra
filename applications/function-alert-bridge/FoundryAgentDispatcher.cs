using System.Net;
using System.Net.Http.Headers;
using System.Text;
using Azure.Core;
using Microsoft.Extensions.Configuration;

namespace AgentBridgeFunction;

public interface IFoundryAgentDispatcher
{
    Task DispatchAsync(string payload, string correlationId, CancellationToken cancellationToken);
}

public sealed class FoundryAgentDispatcher : IFoundryAgentDispatcher
{
    private const int MaximumAttempts = 3;
    private static readonly TimeSpan DefaultRetryDelay = TimeSpan.FromSeconds(2);
    private readonly HttpClient _client;
    private readonly TokenCredential _credential;
    private readonly Uri _agentUri;

    public FoundryAgentDispatcher(HttpClient client, TokenCredential credential, IConfiguration configuration)
    {
        _client = client;
        _credential = credential;
        var endpoint = Required(configuration, "FOUNDRY_PROJECT_ENDPOINT").TrimEnd('/');
        var agentName = Required(configuration, "FOUNDRY_ALERT_AGENT_NAME");
        _agentUri = new Uri($"{endpoint}/agents/{Uri.EscapeDataString(agentName)}/endpoint/protocols/openai/responses?api-version=v1", UriKind.Absolute);
    }

    public async Task DispatchAsync(string payload, string correlationId, CancellationToken cancellationToken)
    {
        var token = await _credential.GetTokenAsync(new TokenRequestContext(new[] { "https://ai.azure.com/.default" }), cancellationToken);
        for (var attempt = 1; attempt <= MaximumAttempts; attempt++)
        {
            using var request = CreateRequest(payload, correlationId, token.Token);
            using var response = await _client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if (response.IsSuccessStatusCode) return;
            if (attempt < MaximumAttempts && IsTransient(response.StatusCode))
            {
                await Task.Delay(RetryDelay(response, attempt), cancellationToken);
                continue;
            }
            throw new FoundryAgentException(response.StatusCode, $"Foundry Hosted Agent returned {(int)response.StatusCode}: {await ReadSafeErrorAsync(response, cancellationToken)}");
        }
    }

    private HttpRequestMessage CreateRequest(string payload, string correlationId, string accessToken)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, _agentUri);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Headers.TryAddWithoutValidation("x-ms-client-request-id", correlationId);
        request.Content = new StringContent($$"""{"input":[{"role":"user","content":{{System.Text.Json.JsonSerializer.Serialize(payload)}}}]}""", Encoding.UTF8, "application/json");
        return request;
    }

    private static bool IsTransient(HttpStatusCode statusCode) => statusCode == HttpStatusCode.RequestTimeout || statusCode == (HttpStatusCode)429 || (int)statusCode >= 500;
    private static TimeSpan RetryDelay(HttpResponseMessage response, int attempt) => response.Headers.RetryAfter?.Delta is { } retryAfter ? retryAfter : TimeSpan.FromMilliseconds(DefaultRetryDelay.TotalMilliseconds * Math.Pow(2, attempt - 1));
    private static async Task<string> ReadSafeErrorAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        return body.Length <= 2048 ? body : body[..2048];
    }
    private static string Required(IConfiguration configuration, string name) => configuration[name] is { Length: > 0 } value ? value : throw new InvalidOperationException($"App setting {name} is required.");
}

public sealed class FoundryAgentException : Exception
{
    public FoundryAgentException(HttpStatusCode statusCode, string message) : base(message) => StatusCode = statusCode;
    public HttpStatusCode StatusCode { get; }
}
