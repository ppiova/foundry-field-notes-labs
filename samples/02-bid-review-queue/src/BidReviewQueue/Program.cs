using System.Globalization;
using System.Threading.RateLimiting;
using BidReviewQueue;
using BidReviewQueue.Components;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.FluentUI.AspNetCore.Components;

// The UI, fixtures and messages are US English; format numbers and money the same way on every machine.
CultureInfo.DefaultThreadCurrentCulture = CultureInfo.DefaultThreadCurrentUICulture = CultureInfo.GetCultureInfo("en-US");
var builder = WebApplication.CreateBuilder(args);
// Serve Fluent UI's packaged assets when running from build output outside Development, as Start-Demo.ps1 does.
builder.WebHost.UseStaticWebAssets();
builder.WebHost.ConfigureKestrel(o => o.Limits.MaxRequestBodySize = 16_384);
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddConcurrencyLimiter("decide", x => { x.PermitLimit = 6; x.QueueLimit = 200; });
});
builder.Services.AddRazorComponents().AddInteractiveServerComponents();
builder.Services.AddFluentUIComponents();

var settings = DecisionSettings.From(builder.Configuration);
var escalation = EscalationSettings.From(builder.Configuration);
// Recorded engine: recording files when configured, otherwise the runs recorded with the sample.
var replay = ReplayProvider.Load(builder.Configuration["BID_REVIEW_REPLAY_FILE"]) ?? ReplayProvider.LoadBundled(ReplayProvider.DemoRecording);
var secondReplay = SecondOpinionReplay.Load(builder.Configuration["BID_REVIEW_ESCALATION_REPLAY_FILE"]) ?? SecondOpinionReplay.LoadBundled(SecondOpinionReplay.DemoRecording);
var credential = settings.Configured ? Credentials.Create(builder.Configuration["FOUNDRY_CREDENTIAL"]) : null;
var foundry = credential is not null
    ? new FoundryDecisionProvider(new HttpClient { Timeout = TimeSpan.FromSeconds(30) }, settings, credential)
    : null;
// The second model is a chat model deployment on the same Foundry resource, called with the same identity.
var secondFoundry = credential is not null && escalation.Configured
    ? new FoundrySecondOpinionProvider(new HttpClient { Timeout = TimeSpan.FromSeconds(60) }, settings.Endpoint!, escalation, credential)
    : null;
builder.Services.AddSingleton(sp => new DecisionService(settings, foundry, replay, sp.GetRequiredService<ILogger<DecisionService>>(), escalation, secondFoundry, secondReplay));

var app = builder.Build();
app.Use(async (ctx, next) =>
{
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    // Fluent UI components set inline style attributes, so styles allow 'unsafe-inline'. Scripts stay same-origin only.
    ctx.Response.Headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'";
    await next();
});
app.UseRateLimiter();
app.UseAntiforgery();
app.MapStaticAssets();

app.MapGet("/api/status", (DecisionService decisions) => new
{
    foundryConfigured = decisions.FoundryConfigured,
    foundryHelp = settings.Problem,
    deployment = settings.Deployment,
    replayAvailable = true,
    replaySummary = replay.Summary,
    runtime = ".NET 11 RC1",
    defaultThreshold = ReviewPolicy.DefaultThreshold,
    pricing = new { usdPerMillionInputTokens = Pricing.UsdPerMillionInputTokens, source = Pricing.Source },
    secondOpinion = new
    {
        foundryConfigured = decisions.SecondOpinionAvailable("foundry"),
        foundryHelp = escalation.Problem,
        deployment = escalation.Deployment,
        model = escalation.Configured ? escalation.ModelName : null,
        replayAvailable = decisions.SecondOpinionAvailable("replay"),
        replaySummary = secondReplay.Summary,
        pricing = new { model = EscalationPricing.Model, usdPerMillionInputTokens = EscalationPricing.UsdPerMillionInputTokens, usdPerMillionOutputTokens = EscalationPricing.UsdPerMillionOutputTokens, source = EscalationPricing.Source },
    },
});

app.MapGet("/api/bid-form", () => DataSets.Demo);

app.MapPost("/api/decide", async (DecideRequest request, DecisionService decisions, CancellationToken ct) =>
{
    if (request.Item is null) return Results.BadRequest(new { error = "Provide a pay item." });
    if (request.Threshold is < ReviewPolicy.MinThreshold or > ReviewPolicy.MaxThreshold)
        return Results.BadRequest(new { error = "The threshold must be between 0.50 and 0.99." });
    // Refuse before deciding, so a request for a second opinion never silently runs without one.
    if (request.SecondOpinion && request.Mode is "foundry" or "replay" && !decisions.SecondOpinionAvailable(request.Mode))
        return Results.Json(new { error = request.Mode == "foundry" && decisions.FoundryConfigured ? $"The second model is not configured. {escalation.Problem}" : "A second opinion is not available for this engine." }, statusCode: StatusCodes.Status503ServiceUnavailable);
    try
    {
        var outcome = await decisions.DecideAsync(request.Item, request.Mode, request.ReverseOptions, ct);
        var result = outcome.Result;
        var review = ReviewPolicy.Evaluate(request.Item, result, outcome.Questions, request.Threshold);
        SecondOpinion? opinion = null;
        string? secondOpinionError = null;
        var secondModel = decisions.SecondModelName(request.Mode);
        if (request.SecondOpinion && EscalationPolicy.Eligible(result, outcome.Questions, request.Threshold))
        {
            try { opinion = await decisions.SecondOpinionAsync(request.Item, outcome.Questions, request.Mode, ct); }
            catch (DecisionFailure failure) { secondOpinionError = failure.Message; }
        }
        var settlement = request.SecondOpinion
            ? EscalationPolicy.Settle(review, result, outcome.Questions, request.Threshold, opinion, false, secondModel)
            : new Settlement(review.AutoAccept ? LineRoute.Rule : LineRoute.Person, [], null);
        return Results.Ok(new
        {
            mode = outcome.Mode,
            model = result.Model,
            elapsedMs = result.ElapsedMs,
            inputTokens = result.InputTokens,
            estimatedCostUsd = Pricing.Estimate(result.InputTokens),
            reverseOptions = request.ReverseOptions,
            questions = outcome.Questions.Select(q => new { q.Name, q.Label, q.Options }),
            answers = result.Answers.ToDictionary(a => a.Key, a => new { a.Value.Choice, a.Value.Probabilities, a.Value.Top, a.Value.Margin }),
            review,
            route = settlement.Route.ToString().ToLowerInvariant(),
            differences = settlement.Differences,
            secondOpinion = opinion is null ? null : new
            {
                opinion.Model,
                opinion.Choices,
                opinion.ElapsedMs,
                opinion.InputTokens,
                opinion.OutputTokens,
                estimatedCostUsd = EscalationPricing.Estimate(opinion.Model, opinion.InputTokens ?? 0, opinion.OutputTokens ?? 0),
            },
            secondOpinionError,
        });
    }
    catch (DecisionFailure failure)
    {
        return Results.Json(new { error = failure.Message }, statusCode: failure.StatusCode);
    }
}).RequireRateLimiting("decide");

app.MapRazorComponents<App>().AddInteractiveServerRenderMode();

app.Run();

record DecideRequest(BidItem? Item, string? Mode, double Threshold = ReviewPolicy.DefaultThreshold, bool ReverseOptions = false, bool SecondOpinion = false);
