using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;

namespace AgentBridgeFunction;

public enum ClientPrincipalAuthorization { NoPrincipal, Denied, Allowed }

public static class ClientPrincipalRoleValidator
{
    public static ClientPrincipalAuthorization Authorize(HttpRequest request, string requiredRole)
    {
        if (!request.Headers.TryGetValue("X-MS-CLIENT-PRINCIPAL", out var encodedPrincipal) || string.IsNullOrWhiteSpace(encodedPrincipal))
            return ClientPrincipalAuthorization.NoPrincipal;

        try
        {
            var principalJson = Encoding.UTF8.GetString(Convert.FromBase64String(encodedPrincipal!));
            using var document = JsonDocument.Parse(principalJson);
            if (!document.RootElement.TryGetProperty("claims", out var claims) || claims.ValueKind != JsonValueKind.Array)
                return ClientPrincipalAuthorization.Denied;

            var hasRole = claims.EnumerateArray().Any(claim =>
                claim.TryGetProperty("typ", out var type) && claim.TryGetProperty("val", out var value) &&
                (string.Equals(type.GetString(), "roles", StringComparison.OrdinalIgnoreCase) || string.Equals(type.GetString(), "role", StringComparison.OrdinalIgnoreCase)) &&
                string.Equals(value.GetString(), requiredRole, StringComparison.Ordinal));
            return hasRole ? ClientPrincipalAuthorization.Allowed : ClientPrincipalAuthorization.Denied;
        }
        catch (FormatException) { return ClientPrincipalAuthorization.Denied; }
        catch (JsonException) { return ClientPrincipalAuthorization.Denied; }
    }
}

public static class CorrelationId
{
    public static string Create(string? requestedValue)
    {
        var value = requestedValue?.Trim();
        return !string.IsNullOrWhiteSpace(value) && value.Length <= 128 && value.All(char.IsLetterOrDigit)
            ? value : Guid.NewGuid().ToString("N");
    }
}
