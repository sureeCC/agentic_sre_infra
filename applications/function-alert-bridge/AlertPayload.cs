using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;

namespace AgentBridgeFunction;

public sealed record PayloadValidationResult(string? Value, string? Error)
{
    public bool IsValid => Error is null;
}

public static class AlertPayloadValidator
{
    public const int MaximumPayloadBytes = 256 * 1024;

    public static PayloadValidationResult Validate(string? payload)
    {
        if (string.IsNullOrWhiteSpace(payload))
            return new(null, "A JSON alert payload is required.");

        if (Encoding.UTF8.GetByteCount(payload) > MaximumPayloadBytes)
            return new(null, $"The alert payload must not exceed {MaximumPayloadBytes} bytes.");

        try
        {
            using var document = JsonDocument.Parse(payload);
            return document.RootElement.ValueKind == JsonValueKind.Object
                ? new(payload, null)
                : new(null, "The alert payload must be a JSON object.");
        }
        catch (JsonException)
        {
            return new(null, "The alert payload must be valid JSON.");
        }
    }
}

public static class AlertPayloadReader
{
    public static async Task<PayloadValidationResult> ReadAndValidateAsync(HttpRequest request, CancellationToken cancellationToken)
    {
        if (request.ContentLength is > AlertPayloadValidator.MaximumPayloadBytes)
            return new(null, $"The alert payload must not exceed {AlertPayloadValidator.MaximumPayloadBytes} bytes.");

        using var reader = new StreamReader(request.Body, Encoding.UTF8, detectEncodingFromByteOrderMarks: true, leaveOpen: false);
        var payload = await reader.ReadToEndAsync(cancellationToken);
        return AlertPayloadValidator.Validate(payload);
    }
}
