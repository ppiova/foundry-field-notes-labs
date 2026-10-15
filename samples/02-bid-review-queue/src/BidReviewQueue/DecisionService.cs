using Azure.Identity;

namespace BidReviewQueue;

public record DecisionOutcome(IReadOnlyList<ChoiceQuestion> Questions, DecisionResult Result, string Mode);

/// <summary>A failure with the HTTP status and the message shown to the user. Nothing is substituted in its place.</summary>
sealed class DecisionFailure(int statusCode, string message) : Exception(message)
{
    public int StatusCode => statusCode;
}

/// <summary>
/// Selects the decision source and translates failures. The API and the Blazor UI both use it. Both sources return
/// real model answers: live requests, or responses recorded from a live run. The optional second model follows the
/// same engine: live requests with the live engine, recorded second opinions with the recorded engine.
/// </summary>
sealed class DecisionService(DecisionSettings settings, IDecisionProvider? foundry, ReplayProvider replay, ILogger<DecisionService> logger,
    EscalationSettings? escalation = null, ISecondOpinionProvider? secondFoundry = null, SecondOpinionReplay? secondReplay = null)
{
    const int DecisionSeconds = 30, SecondOpinionSeconds = 45;

    public DecisionSettings Settings => settings;
    public ReplayProvider Replay => replay;
    public bool FoundryConfigured => foundry is not null;
    public EscalationSettings Escalation { get; } = escalation ?? EscalationSettings.From(null, null);
    public SecondOpinionReplay? SecondOpinionReplay => secondReplay;

    /// <summary>Whether a second model can answer for this engine.</summary>
    public bool SecondOpinionAvailable(string? mode) => mode switch
    {
        "foundry" => foundry is not null && secondFoundry is not null,
        "replay" => secondReplay is not null,
        _ => false,
    };

    /// <summary>The name shown for the second model with this engine.</summary>
    public string SecondModelName(string? mode) => mode == "replay" && secondReplay is not null ? secondReplay.ModelName : Escalation.ModelName;

    public async Task<DecisionOutcome> DecideAsync(BidItem item, string? mode, bool reverseOptions, CancellationToken ct)
    {
        if (item.Validate() is { } invalid) throw new DecisionFailure(StatusCodes.Status400BadRequest, invalid);
        IDecisionProvider provider = mode switch
        {
            "foundry" => foundry ?? throw new DecisionFailure(StatusCodes.Status503ServiceUnavailable, $"Microsoft-Decision-1 is not configured. {settings.Problem}"),
            "replay" => replay,
            _ => throw new DecisionFailure(StatusCodes.Status400BadRequest, "Invalid mode. Use foundry or replay."),
        };

        var questions = PayItemQuestions.For(item.Description);
        var result = await Guard(token => provider.DecideAsync(item.ToState(), questions, reverseOptions, token),
            DecisionSeconds, "The decision", "No simulated fallback was generated.", ct);
        return new(questions, result, provider.Mode);
    }

    /// <summary>Asks the second model the same questions. A failure leaves the line with a person; nothing is substituted.</summary>
    public async Task<SecondOpinion> SecondOpinionAsync(BidItem item, IReadOnlyList<ChoiceQuestion> questions, string? mode, CancellationToken ct)
    {
        if (item.Validate() is { } invalid) throw new DecisionFailure(StatusCodes.Status400BadRequest, invalid);
        ISecondOpinionProvider provider = mode switch
        {
            "foundry" when foundry is null => throw new DecisionFailure(StatusCodes.Status503ServiceUnavailable, $"Microsoft-Decision-1 is not configured. {settings.Problem}"),
            "foundry" => secondFoundry ?? throw new DecisionFailure(StatusCodes.Status503ServiceUnavailable, $"The second model is not configured. {Escalation.Problem}"),
            "replay" => secondReplay ?? throw new DecisionFailure(StatusCodes.Status503ServiceUnavailable, "No recorded second opinions are available."),
            _ => throw new DecisionFailure(StatusCodes.Status400BadRequest, "Invalid mode. Use foundry or replay."),
        };
        return await Guard(token => provider.AskAsync(item.ToState(), questions, token),
            SecondOpinionSeconds, "The second opinion", "The line stays with a person.", ct);
    }

    async Task<T> Guard<T>(Func<CancellationToken, Task<T>> call, int seconds, string what, string consequence, CancellationToken ct)
    {
        try
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(TimeSpan.FromSeconds(seconds));
            return await call(timeout.Token);
        }
        catch (DecisionApiException ex)
        {
            logger.LogWarning("{What} returned {Status}", what, (int)ex.Status);
            var status = (int)ex.Status == StatusCodes.Status429TooManyRequests ? StatusCodes.Status429TooManyRequests : StatusCodes.Status502BadGateway;
            throw new DecisionFailure(status, $"{ex.Message} {consequence}");
        }
        catch (InvalidDataException ex)
        {
            logger.LogWarning("{What} failed validation: {Reason}", what, ex.Message);
            throw new DecisionFailure(StatusCodes.Status502BadGateway, $"{what} did not match its response contract: {ex.Message} {consequence}");
        }
        catch (ReplayMissException ex)
        {
            throw new DecisionFailure(StatusCodes.Status404NotFound, ex.Message);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            throw new DecisionFailure(StatusCodes.Status504GatewayTimeout, $"{what} took longer than {seconds} seconds. Please try again.");
        }
        catch (Exception ex) when (ex is HttpRequestException or AuthenticationFailedException or CredentialUnavailableException)
        {
            logger.LogWarning("Could not reach Foundry: {ExceptionType}", ex.GetType().Name);
            throw new DecisionFailure(StatusCodes.Status502BadGateway, $"Could not reach Foundry or get a token. Run az login and check FOUNDRY_RESOURCE_ENDPOINT. {consequence}");
        }
    }
}

/// <summary>Display helpers shared by the components. Money is US dollars; numbers use invariant formatting.</summary>
static class Format
{
    static readonly System.Globalization.CultureInfo Us = System.Globalization.CultureInfo.GetCultureInfo("en-US");

    static readonly Dictionary<string, string> Labels = new(StringComparer.Ordinal)
    {
        ["sanitary_gravity"] = "Sanitary gravity", ["force_main"] = "Force main", ["water"] = "Water", ["storm"] = "Storm",
        ["general"] = "General", ["unclear"] = "Unclear", ["furnish_install"] = "Furnish and install", ["furnish_only"] = "Furnish only",
        ["install_only"] = "Install only", ["remove_abandon"] = "Remove or abandon", ["connect_adjust"] = "Connect or adjust",
        ["support_work"] = "Support work", ["restoration"] = "Restoration", ["general_conditions"] = "General conditions", ["none"] = "None of these",
    };

    public static string Usd(decimal amount) => amount.ToString("C0", Us);
    public static string Cents(decimal amount) => amount.ToString("C2", Us);
    public static string Quantity(decimal quantity) => quantity.ToString("#,0.##", Us);
    public static string Probability(double p) => p.ToString("0.00", Us);
    public static string Seconds(long milliseconds) => $"{(milliseconds / 1000.0).ToString("0.0", Us)} s";
    public static string Label(string key) => Labels.GetValueOrDefault(key, key);
}

/// <summary>A reviewer's change to one answer of one pay item.</summary>
public record LineEdit(string Number, string Question, string? Value, string ModelChoice);
