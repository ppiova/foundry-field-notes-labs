using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Azure.Core;

namespace BidReviewQueue;

/// <summary>An option the application offers. The model can only select one of these keys.</summary>
public record DecisionOption(string Key, string Description);

/// <summary>A closed multiple-choice question in the Microsoft-Decision-1 request format.</summary>
public record ChoiceQuestion(string Name, string Label, string Instructions, IReadOnlyList<DecisionOption> Options);

public record ChoiceAnswer(string Choice, IReadOnlyDictionary<string, double> Probabilities)
{
    public double Top => Probabilities[Choice];
    public double Margin => Top - Probabilities.Where(p => p.Key != Choice).Select(p => p.Value).DefaultIfEmpty(0).Max();
}

/// <summary>
/// A request body kept for the inspector, without the host or the token. A live call keeps the body it sent. A recording
/// stores only the response, so replay rebuilds the body from the current question definitions and marks it rebuilt.
/// </summary>
public record SentRequest(string Body, bool Rebuilt);

public record DecisionResult(IReadOnlyDictionary<string, ChoiceAnswer> Answers, int? InputTokens, string Model, long ElapsedMs, string? RawResponse = null)
{
    public SentRequest? Request { get; init; }
}

interface IDecisionProvider
{
    string Mode { get; }
    Task<DecisionResult> DecideAsync(JsonObject state, IReadOnlyList<ChoiceQuestion> questions, bool reverseOptions, CancellationToken ct);
}

/// <summary>Builds requests for, and validates responses from, the decision endpoint.</summary>
static class DecisionWire
{
    public const string Path = "providers/microsoft/v1/systemone";
    public const string Scope = "https://cognitiveservices.azure.com/.default";
    public const double SumTolerance = 0.02;

    public static JsonObject BuildRequest(string deployment, JsonObject state, IReadOnlyList<ChoiceQuestion> questions, bool reverseOptions)
    {
        var questionNodes = new JsonObject();
        foreach (var question in questions)
        {
            var criteria = new JsonObject();
            var options = reverseOptions ? Enumerable.Reverse(question.Options) : question.Options;
            foreach (var option in options) criteria[option.Key] = option.Description;
            questionNodes[question.Name] = new JsonObject
            {
                ["type"] = "choice",
                ["instructions"] = question.Instructions,
                ["criteria"] = criteria,
            };
        }
        return new JsonObject { ["model"] = deployment, ["state"] = state.DeepClone(), ["questions"] = questionNodes };
    }

    /// <summary>Accepts only answers that choose an offered option and give a probability for every offered option.</summary>
    public static DecisionResult ParseResponse(string json, IReadOnlyList<ChoiceQuestion> questions, long elapsedMs)
    {
        try
        {
            if (JsonNode.Parse(json) is not JsonObject body || body["answers"] is not JsonObject answers)
                throw new InvalidDataException("The response has no answers object.");
            var parsed = new Dictionary<string, ChoiceAnswer>(StringComparer.Ordinal);
            foreach (var question in questions)
            {
                if (answers[question.Name] is not JsonObject answer)
                    throw new InvalidDataException($"The response has no answer for '{question.Name}'.");
                if (Text(answer["type"]) != "choice")
                    throw new InvalidDataException($"'{question.Name}' is not a choice answer.");
                var offered = question.Options.Select(o => o.Key).ToHashSet(StringComparer.Ordinal);
                var choice = Text(answer["choice"]);
                if (choice is null || !offered.Contains(choice))
                    throw new InvalidDataException($"'{question.Name}' selected an option the application did not offer.");
                if (answer["probabilities"] is not JsonObject probabilityNodes)
                    throw new InvalidDataException($"'{question.Name}' has no per-option probabilities.");
                var probabilities = new Dictionary<string, double>(StringComparer.Ordinal);
                foreach (var (key, node) in probabilityNodes)
                {
                    if (!offered.Contains(key))
                        throw new InvalidDataException($"'{question.Name}' scored an option the application did not offer.");
                    if (Number(node) is not { } p || p < 0 || p > 1)
                        throw new InvalidDataException($"'{question.Name}' returned a probability outside 0 to 1.");
                    probabilities[key] = p;
                }
                if (probabilities.Count != offered.Count)
                    throw new InvalidDataException($"'{question.Name}' did not score every offered option.");
                if (Math.Abs(probabilities.Values.Sum() - 1) > SumTolerance)
                    throw new InvalidDataException($"'{question.Name}' probabilities do not sum to 1.");
                parsed[question.Name] = new ChoiceAnswer(choice, probabilities);
            }
            var usage = body["usage"] as JsonObject;
            var tokens = Integer(usage?["input_tokens"]) ?? Integer(usage?["prompt_tokens"]);
            return new DecisionResult(parsed, tokens, Text(body["model"]) ?? "unknown", elapsedMs, json);
        }
        catch (Exception ex) when (ex is JsonException or ArgumentException or InvalidOperationException or FormatException)
        {
            throw new InvalidDataException("The response is not valid decision JSON.", ex);
        }
    }

    static string? Text(JsonNode? node) => node is JsonValue v && v.TryGetValue<string>(out var s) ? s : null;
    static double? Number(JsonNode? node) => node is JsonValue v && v.TryGetValue<double>(out var d) && double.IsFinite(d) ? d : null;
    static int? Integer(JsonNode? node) => node is JsonValue v && v.TryGetValue<int>(out var i) && i >= 0 ? i : null;
}

/// <summary>Configuration for the live path. A problem message means the live path stays disabled.</summary>
partial record DecisionSettings(Uri? Endpoint, string? Deployment, string? Problem)
{
    public bool Configured => Problem is null;

    public static DecisionSettings From(IConfiguration configuration) =>
        From(configuration["FOUNDRY_RESOURCE_ENDPOINT"], configuration["FOUNDRY_DECISION_DEPLOYMENT"]);

    public static DecisionSettings From(string? endpoint, string? deployment)
    {
        if (string.IsNullOrWhiteSpace(endpoint) && string.IsNullOrWhiteSpace(deployment))
            return new(null, null, "Set FOUNDRY_RESOURCE_ENDPOINT and FOUNDRY_DECISION_DEPLOYMENT, sign in with az login, and restart.");
        if (!Uri.TryCreate(endpoint?.Trim(), UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps)
            return new(null, null, "FOUNDRY_RESOURCE_ENDPOINT must be an https URL.");
        if (uri.AbsolutePath.Contains("/api/projects", StringComparison.OrdinalIgnoreCase))
            return new(null, null, "FOUNDRY_RESOURCE_ENDPOINT is a project endpoint. Use the resource endpoint from the deployment details page, without /api/projects/.");
        if (string.IsNullOrWhiteSpace(deployment) || !DeploymentName().IsMatch(deployment.Trim()))
            return new(null, null, "Set FOUNDRY_DECISION_DEPLOYMENT to your deployment name (letters, digits, '.', '_' or '-').");
        return new(new Uri(uri.GetLeftPart(UriPartial.Authority) + "/"), deployment.Trim(), null);
    }

    [GeneratedRegex("^[A-Za-z0-9._-]{1,64}$")]
    private static partial Regex DeploymentName();
}

sealed class DecisionApiException(HttpStatusCode status, string api = "The decision API") : Exception(Describe(status, api))
{
    public HttpStatusCode Status => status;

    // Status meanings follow the troubleshooting table in the Microsoft Learn article for Microsoft-Decision-1.
    static string Describe(HttpStatusCode status, string api) => (int)status switch
    {
        400 => $"{api} rejected the request shape (HTTP 400). Check the question definitions.",
        401 => "Authentication failed (HTTP 401). Run az login again.",
        403 => "Access denied (HTTP 403). Verify your role assignment for this deployment.",
        404 => "Endpoint or deployment not found (HTTP 404). Use the resource endpoint from the deployment details page and check the deployment name.",
        422 => "The deployment name or a question definition is not supported (HTTP 422).",
        429 => "The deployment rate limit was exceeded (HTTP 429). Wait and retry, or request more quota.",
        var code => $"{api} returned HTTP {code}.",
    };
}

/// <summary>Calls Microsoft-Decision-1 on a Foundry resource with a Microsoft Entra token from Azure CLI.</summary>
sealed class FoundryDecisionProvider(HttpClient http, DecisionSettings settings, TokenCredential credential) : IDecisionProvider
{
    static readonly string[] Scopes = [DecisionWire.Scope];
    readonly SemaphoreSlim tokenLock = new(1, 1);
    AccessToken token;

    public string Mode => "foundry";
    public string Deployment { get; } = settings.Deployment ?? throw new ArgumentException("Settings are not configured.", nameof(settings));
    public Uri RequestUri { get; } = new(settings.Endpoint ?? throw new ArgumentException("Settings are not configured.", nameof(settings)), DecisionWire.Path);

    public async Task<DecisionResult> DecideAsync(JsonObject state, IReadOnlyList<ChoiceQuestion> questions, bool reverseOptions, CancellationToken ct)
    {
        var body = DecisionWire.BuildRequest(Deployment, state, questions, reverseOptions).ToJsonString();
        var bearer = await GetTokenAsync(ct);
        for (var attempt = 1; ; attempt++)
        {
            // StringContent sends Content-Length instead of a chunked body.
            using var request = new HttpRequestMessage(HttpMethod.Post, RequestUri) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearer);
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            var watch = Stopwatch.StartNew();
            using var response = await http.SendAsync(request, ct);
            var text = await response.Content.ReadAsStringAsync(ct);
            watch.Stop();
            if (response.StatusCode == HttpStatusCode.TooManyRequests && attempt == 1)
            {
                await Task.Delay(RetryDelay(response), ct);
                continue;
            }
            if (!response.IsSuccessStatusCode) throw new DecisionApiException(response.StatusCode);
            return DecisionWire.ParseResponse(text, questions, watch.ElapsedMilliseconds) with { Request = new(body, Rebuilt: false) };
        }
    }

    async Task<string> GetTokenAsync(CancellationToken ct)
    {
        await tokenLock.WaitAsync(ct);
        try
        {
            if (token.ExpiresOn <= DateTimeOffset.UtcNow.AddMinutes(5))
                token = await credential.GetTokenAsync(new TokenRequestContext(Scopes), ct);
            return token.Token;
        }
        finally { tokenLock.Release(); }
    }

    static TimeSpan RetryDelay(HttpResponseMessage response)
    {
        var max = TimeSpan.FromSeconds(5);
        if (response.Headers.TryGetValues("retry-after-ms", out var values)
            && double.TryParse(values.FirstOrDefault(), NumberStyles.Float, CultureInfo.InvariantCulture, out var ms) && ms >= 0)
            return TimeSpan.FromMilliseconds(Math.Min(ms, max.TotalMilliseconds));
        if (response.Headers.RetryAfter?.Delta is { } delta) return delta < max ? delta : max;
        return TimeSpan.FromSeconds(1);
    }
}

/// <summary>
/// One explicit credential instead of a chain: Azure CLI on a developer machine, or the app's system-assigned
/// managed identity when it runs in Azure App Service.
/// </summary>
static class Credentials
{
    public static TokenCredential Create(string? mode) => mode switch
    {
        null or "" or "azure-cli" => new Azure.Identity.AzureCliCredential(),
        "managed-identity" => new Azure.Identity.ManagedIdentityCredential(Azure.Identity.ManagedIdentityId.SystemAssigned),
        _ => throw new InvalidOperationException("FOUNDRY_CREDENTIAL must be azure-cli or managed-identity."),
    };
}

static class Pricing
{
    public const decimal UsdPerMillionInputTokens = 0.042m;
    public const string Source = "List price in Microsoft's announcement of 2026-10-09; output tokens free. Verify current Azure pricing before relying on it.";

    public static decimal? Estimate(int? inputTokens) => inputTokens is { } t ? t * UsdPerMillionInputTokens / 1_000_000m : null;
}
