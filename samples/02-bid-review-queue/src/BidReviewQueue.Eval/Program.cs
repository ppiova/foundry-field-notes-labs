using System.Globalization;
using System.Text;
using Azure.Identity;
using BidReviewQueue;

CultureInfo.DefaultThreadCurrentCulture = CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;

const string usage = """
    Usage: dotnet run --project samples/02-bid-review-queue/src/BidReviewQueue.Eval -- [options]
      --mode replay|foundry              Decision source (default: replay of the run recorded with the sample)
      --dataset labeled|demo             Labeled synthetic items, or the demo bid form (default: labeled)
      --record <file.jsonl>              Foundry only: save raw responses for replay
      --replay <file.jsonl>              Replay only: another recording to evaluate
      --out <file.md>                    Report path (default: artifacts/bid-review-queue/...)
      --concurrency <1-8>                Parallel requests (default: 4)
      --max-rpm <n>                      Start at most n requests per minute, to stay under the deployment's rate limit (default: no limit)
      --no-order-check                   Skip the reversed-option-order pass
      --escalation replay|foundry        Ask a second model about lines that could need review (default: off)
      --escalation-replay <file.jsonl>   Escalation replay only: another second-opinion recording
      --record-escalation <file.jsonl>   Escalation foundry only: save raw second-model responses for replay
    Foundry mode reads FOUNDRY_RESOURCE_ENDPOINT and FOUNDRY_DECISION_DEPLOYMENT and signs in with Azure CLI.
    Escalation foundry also reads FOUNDRY_ESCALATION_DEPLOYMENT and, as a display label, FOUNDRY_ESCALATION_MODEL.
    """;

var options = new Dictionary<string, string>(StringComparer.Ordinal);
var orderCheck = true;
// Unknown names are errors: a typo such as --mdoe must not silently run a different source.
string[] known = ["mode", "dataset", "record", "replay", "out", "concurrency", "max-rpm", "escalation", "escalation-replay", "record-escalation"];
for (var i = 0; i < args.Length; i++)
{
    if (args[i] == "--no-order-check") { orderCheck = false; continue; }
    if (args[i] is "--help" or "-h") { Console.WriteLine(usage); return 0; }
    if (!args[i].StartsWith("--") || !known.Contains(args[i][2..]) || i + 1 >= args.Length)
    {
        Console.Error.WriteLine($"Unknown or incomplete option: {args[i]}");
        Console.WriteLine(usage);
        return 2;
    }
    options[args[i][2..]] = args[++i];
}
var mode = options.GetValueOrDefault("mode", "replay");
var dataset = options.GetValueOrDefault("dataset", "labeled");
var escalationMode = options.GetValueOrDefault("escalation");
if (mode is not ("foundry" or "replay") || dataset is not ("labeled" or "demo") || escalationMode is not (null or "foundry" or "replay")
    || !int.TryParse(options.GetValueOrDefault("concurrency", "4"), out var concurrency) || concurrency is < 1 or > 8
    || !int.TryParse(options.GetValueOrDefault("max-rpm", "0"), out var maxRpm) || maxRpm < 0)
{
    Console.WriteLine(usage);
    return 2;
}

IDecisionProvider provider;
string source;
var settings = DecisionSettings.From(Environment.GetEnvironmentVariable("FOUNDRY_RESOURCE_ENDPOINT"), Environment.GetEnvironmentVariable("FOUNDRY_DECISION_DEPLOYMENT"));
switch (mode)
{
    case "foundry":
        if (!settings.Configured) { Console.Error.WriteLine(settings.Problem); return 2; }
        provider = new FoundryDecisionProvider(new HttpClient { Timeout = TimeSpan.FromSeconds(30) }, settings, new AzureCliCredential());
        source = $"Microsoft-Decision-1 through Foundry deployment `{settings.Deployment}`. Live requests.";
        break;
    default:
        // Without --replay, use the live run recorded with the sample for the chosen dataset.
        var replay = ReplayProvider.Load(options.GetValueOrDefault("replay"))
            ?? ReplayProvider.LoadBundled(dataset == "labeled" ? ReplayProvider.LabeledRecording : ReplayProvider.DemoRecording);
        provider = replay;
        source = $"Replay of recorded Microsoft-Decision-1 responses: {replay.Summary}. No new requests; latency is the latency measured when recorded.";
        break;
}

ISecondOpinionProvider? second = null;
string secondSource = "", secondModel = "";
var escalation = EscalationSettings.From(Environment.GetEnvironmentVariable("FOUNDRY_ESCALATION_DEPLOYMENT"), Environment.GetEnvironmentVariable("FOUNDRY_ESCALATION_MODEL"));
if (options.ContainsKey("escalation-replay") && escalationMode != "replay") { Console.Error.WriteLine("--escalation-replay requires --escalation replay."); return 2; }
// A recording must cover lines that need review only when the options are reversed, as the page can reverse them.
if (options.ContainsKey("record-escalation") && !orderCheck) { Console.Error.WriteLine("--record-escalation needs the reversed-option-order pass. Remove --no-order-check."); return 2; }
switch (escalationMode)
{
    case "foundry":
        if (!settings.Configured) { Console.Error.WriteLine(settings.Problem); return 2; }
        if (!escalation.Configured) { Console.Error.WriteLine(escalation.Problem); return 2; }
        second = new FoundrySecondOpinionProvider(new HttpClient { Timeout = TimeSpan.FromSeconds(60) }, settings.Endpoint!, escalation, new AzureCliCredential());
        secondModel = escalation.ModelName;
        secondSource = $"{secondModel} through Foundry deployment `{escalation.Deployment}`, Responses API with strict structured outputs. Live requests.";
        break;
    case "replay":
        var recorded = SecondOpinionReplay.Load(options.GetValueOrDefault("escalation-replay"))
            ?? SecondOpinionReplay.LoadBundled(dataset == "labeled" ? SecondOpinionReplay.LabeledRecording : SecondOpinionReplay.DemoRecording);
        second = recorded;
        secondModel = recorded.ModelName;
        secondSource = $"Replay of recorded second opinions: {recorded.Summary}. No new requests; latency is the latency measured when recorded.";
        break;
}

var items = dataset == "labeled"
    ? DataSets.Labeled.Items.Select(i => (Item: i.ToItem(), Expected: (IReadOnlyDictionary<string, string>?)i.Expected)).ToList()
    : DataSets.Demo.Items.Select(i => (Item: i, Expected: (IReadOnlyDictionary<string, string>?)null)).ToList();

StreamWriter? recorder = null;
if (options.TryGetValue("record", out var recordPath))
{
    if (mode != "foundry") { Console.Error.WriteLine("--record is only available in foundry mode."); return 2; }
    // One file per run, so a replay never mixes deployments or dates without saying so.
    if (File.Exists(recordPath)) { Console.Error.WriteLine($"{recordPath} already exists. Record each run to a new file."); return 2; }
    Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(recordPath))!);
    recorder = new StreamWriter(recordPath, append: false, new UTF8Encoding(false));
}
StreamWriter? secondRecorder = null;
if (options.TryGetValue("record-escalation", out var secondRecordPath))
{
    if (escalationMode != "foundry") { Console.Error.WriteLine("--record-escalation is only available with --escalation foundry."); return 2; }
    if (File.Exists(secondRecordPath) || secondRecordPath == recordPath) { Console.Error.WriteLine($"{secondRecordPath} already exists. Record each run to a new file."); return 2; }
    Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(secondRecordPath))!);
    secondRecorder = new StreamWriter(secondRecordPath, append: false, new UTF8Encoding(false));
}
var recordLock = new Lock();

// Spaces request starts evenly so a run stays under a requests-per-minute limit instead of relying on retries.
var interval = maxRpm > 0 ? TimeSpan.FromMinutes(1) / maxRpm : TimeSpan.Zero;
var paceLock = new Lock();
var nextStart = DateTimeOffset.UtcNow;
async Task Pace()
{
    if (interval == TimeSpan.Zero) return;
    TimeSpan wait;
    lock (paceLock)
    {
        var now = DateTimeOffset.UtcNow;
        var start = nextStart > now ? nextStart : now;
        nextStart = start + interval;
        wait = start - now;
    }
    if (wait > TimeSpan.Zero) await Task.Delay(wait);
}

async Task<Outcome[]> RunPass(bool reverse)
{
    using var gate = new SemaphoreSlim(concurrency);
    return await Task.WhenAll(items.Select(async entry =>
    {
        var questions = PayItemQuestions.For(entry.Item.Description);
        await gate.WaitAsync();
        try
        {
            await Pace();
            var result = await provider.DecideAsync(entry.Item.ToState(), questions, reverse, CancellationToken.None);
            if (recorder is not null && result.RawResponse is not null)
                lock (recordLock) recorder.WriteLine(ReplayProvider.Serialize(new Recording(DateTimeOffset.UtcNow, settings.Deployment!, result.Model, reverse, entry.Item.Description, entry.Item.Unit, result.ElapsedMs, result.RawResponse)));
            return new Outcome(entry.Item, entry.Expected, questions, result, null);
        }
        catch (Exception ex) when (ex is DecisionApiException or InvalidDataException or ReplayMissException or HttpRequestException or TaskCanceledException or AuthenticationFailedException or CredentialUnavailableException)
        {
            return new Outcome(entry.Item, entry.Expected, questions, null, ex is TaskCanceledException ? "Timed out after 30 seconds." : ex.Message);
        }
        finally { gate.Release(); }
    }));
}

var started = DateTimeOffset.UtcNow;
Console.WriteLine($"Deciding {items.Count} pay items ({mode}, {dataset})...");
var forward = await RunPass(false);
var reversed = orderCheck ? await RunPass(true) : null;
recorder?.Dispose();

// Second opinions for every line that could need review at some threshold, in either option order, so a replay
// covers any threshold the UI slider can choose. The second model always sees the original option order.
var opinions = new Dictionary<string, SecondOpinion>(StringComparer.Ordinal);
var secondErrors = new List<string>();
if (second is not null)
{
    var candidates = forward.Select((o, i) => (Forward: o, Reversed: reversed?[i]))
        .Where(p => p.Forward.Result is { } f && (EscalationPolicy.Eligible(f, p.Forward.Questions, ReviewPolicy.MaxThreshold)
            || p.Reversed?.Result is { } r && EscalationPolicy.Eligible(r, p.Reversed.Questions, ReviewPolicy.MaxThreshold)))
        .Select(p => p.Forward).ToList();
    Console.WriteLine($"Asking {secondModel} about {candidates.Count} pay items...");
    using var gate = new SemaphoreSlim(concurrency);
    var asked = await Task.WhenAll(candidates.Select(async o =>
    {
        await gate.WaitAsync();
        try
        {
            await Pace();
            var opinion = await second.AskAsync(o.Item.ToState(), o.Questions, CancellationToken.None);
            if (secondRecorder is not null && opinion.RawResponse is not null)
                lock (recordLock) secondRecorder.WriteLine(ReplayProvider.Serialize(new Recording(DateTimeOffset.UtcNow, escalation.Deployment!, opinion.Model, false, o.Item.Description, o.Item.Unit, opinion.ElapsedMs, opinion.RawResponse)));
            return (o.Item, Opinion: (SecondOpinion?)opinion, Error: (string?)null);
        }
        catch (Exception ex) when (ex is DecisionApiException or InvalidDataException or ReplayMissException or HttpRequestException or TaskCanceledException or AuthenticationFailedException or CredentialUnavailableException)
        {
            return (o.Item, Opinion: null, Error: ex is TaskCanceledException ? "Timed out: the retry got no answer within 60 seconds." : ex.Message);
        }
        finally { gate.Release(); }
    }));
    foreach (var (item, opinion, error) in asked)
    {
        if (opinion is not null) opinions[item.Number] = opinion;
        else secondErrors.Add(error!);
    }
}
secondRecorder?.Dispose();

var report = new StringBuilder();
report.AppendLine("# Bid Review Queue evaluation").AppendLine();
report.AppendLine($"- Run: {started:yyyy-MM-dd HH:mm} UTC");
report.AppendLine($"- Source: {source}");
var models = forward.Where(o => o.Result is not null).Select(o => o.Result!.Model).Distinct().ToList();
report.AppendLine($"- Model reported in responses: {(models.Count == 0 ? "none" : string.Join(", ", models))}");
report.AppendLine(dataset == "labeled"
    ? $"- Dataset: {items.Count} synthetic pay items with maintainer-authored labels. {DataSets.Labeled.Note}"
    : $"- Dataset: demo bid form \"{DataSets.Demo.Title}\", {items.Count} pay items, unlabeled. {DataSets.Demo.Note}");
var errors = forward.Concat(reversed ?? []).Where(o => o.Error is not null).ToList();
report.AppendLine($"- Requests: {forward.Length} in original option order{(reversed is null ? "" : $", {reversed.Length} with every option list reversed")}; {errors.Count} failed");
if (second is not null) report.AppendLine($"- Second model: {secondSource} {opinions.Count + secondErrors.Count} requests; {secondErrors.Count} failed");
if (maxRpm > 0) report.AppendLine($"- Pacing: at most {maxRpm} request starts per minute, {concurrency} in parallel");
report.AppendLine();

var ok = forward.Where(o => o.Result is not null).ToList();
var thresholds = new[] { 0.80, 0.90, 0.95, 0.99 };
if (dataset == "labeled")
{
    report.AppendLine("## Accuracy by question").AppendLine();
    report.AppendLine("| Question | Asked | Correct | Accuracy | Mean Brier score |").AppendLine("| --- | ---: | ---: | ---: | ---: |");
    foreach (var name in new[] { "system", "work_type", "diameter", "material", "depth_band" })
    {
        var scored = ok.Where(o => o.Expected!.ContainsKey(name)).Select(o => (Answer: o.Result!.Answers[name], Expected: o.Expected![name])).ToList();
        if (scored.Count == 0) continue;
        var correct = scored.Count(s => s.Answer.Choice == s.Expected);
        report.AppendLine($"| {name} | {scored.Count} | {correct} | {Percent(correct, scored.Count)} | {scored.Average(s => Scoring.Brier(s.Answer, s.Expected)):0.000} |");
    }
    report.AppendLine().AppendLine("Brier score: 0 is perfect; lower is better. It penalizes confident wrong answers more than hesitant ones.").AppendLine();

    var wrongAnswers = ok.SelectMany(o => o.Expected!
            .Where(e => o.Result!.Answers[e.Key].Choice != e.Value)
            .Select(e => $"- {o.Item.Number} `{o.Item.Description}` — {e.Key}: expected `{e.Value}`, got `{o.Result!.Answers[e.Key].Choice}` at {o.Result!.Answers[e.Key].Top:0.00}"))
        .ToList();
    if (wrongAnswers.Count > 0)
    {
        report.AppendLine("### Answers that differ from the labels").AppendLine();
        wrongAnswers.ForEach(w => report.AppendLine(w));
        report.AppendLine().AppendLine("A difference can be a model error or a debatable label; read each one before drawing conclusions.").AppendLine();
    }

    report.AppendLine("## Automatic acceptance by threshold").AppendLine();
    report.AppendLine("A line is accepted automatically only when every answer clears the threshold, none is `unclear`, and each selected option is the most probable one.").AppendLine();
    report.AppendLine("| Threshold | Accepted automatically | Wrong among accepted | Sent to review | Wrong lines caught by review |").AppendLine("| ---: | ---: | ---: | ---: | ---: |");
    foreach (var t in thresholds)
    {
        var lines = ok.Select(o => (Review: ReviewPolicy.Evaluate(o.Item, o.Result!, o.Questions, t), Wrong: o.Expected!.Any(e => o.Result!.Answers[e.Key].Choice != e.Value))).ToList();
        var accepted = lines.Where(l => l.Review.AutoAccept).ToList();
        var wrong = lines.Count(l => l.Wrong);
        var caught = lines.Count(l => l.Wrong && !l.Review.AutoAccept);
        report.AppendLine($"| {t:0.00} | {accepted.Count} of {lines.Count} ({Percent(accepted.Count, lines.Count)}) | {accepted.Count(l => l.Wrong)} | {lines.Count - accepted.Count} | {caught} of {wrong} |");
    }
    report.AppendLine();

    report.AppendLine("## Reliability").AppendLine();
    report.AppendLine("Every answer, grouped by the probability of the selected option. In a calibrated model, accuracy in each row is close to the mean probability.").AppendLine();
    report.AppendLine("| Probability | Answers | Mean probability | Accuracy |").AppendLine("| --- | ---: | ---: | ---: |");
    var points = ok.SelectMany(o => o.Expected!.Select(e => (o.Result!.Answers[e.Key].Top, o.Result!.Answers[e.Key].Choice == e.Value)));
    foreach (var bin in Scoring.Reliability(points, [0, 0.5, 0.7, 0.8, 0.9, 0.95, 0.99, 1.0]).Where(b => b.Count > 0))
        report.AppendLine($"| {bin.Low:0.00}–{bin.High:0.00} | {bin.Count} | {bin.MeanProbability:0.000} | {bin.Accuracy * 100:0.0}% |");
    report.AppendLine();
}
else
{
    report.AppendLine("## Review queue by threshold").AppendLine();
    var total = ok.Sum(o => o.Item.Amount);
    report.AppendLine($"Engineer's estimate of the decided lines: {Usd(total)}.").AppendLine();
    report.AppendLine("| Threshold | Accepted automatically | Sent to review | Amount in review | Review priority score in review |").AppendLine("| ---: | ---: | ---: | ---: | ---: |");
    foreach (var t in thresholds)
    {
        var reviews = ok.Select(o => ReviewPolicy.Evaluate(o.Item, o.Result!, o.Questions, t)).ToList();
        var queue = reviews.Where(r => !r.AutoAccept).ToList();
        report.AppendLine($"| {t:0.00} | {reviews.Count - queue.Count} of {reviews.Count} | {queue.Count} | {Usd(queue.Sum(r => r.Amount))} | {queue.Sum(r => r.PriorityScore):N0} |");
    }
    report.AppendLine();
}

if (second is not null)
{
    report.AppendLine($"## Second opinion from {secondModel}").AppendLine();
    report.AppendLine($"Asked about {opinions.Count + secondErrors.Count} pay items that could need review at some threshold up to 0.99: no Unclear answer, every selected option the most probable, and a weakest probability below 0.99 in either option order. A line below the threshold is accepted by agreement only when {secondModel} chooses the same option as Microsoft-Decision-1 for every question. Any difference, or a failed request, sends the line to a person.").AppendLine();
    var asked = ok.Where(o => opinions.ContainsKey(o.Item.Number)).ToList();
    var disagreements = asked.SelectMany(o => o.Questions
            .Where(q => opinions[o.Item.Number].Choices[q.Name] != o.Result!.Answers[q.Name].Choice)
            .Select(q => $"- {o.Item.Number} `{o.Item.Description}` — {q.Name}: Microsoft-Decision-1 `{o.Result!.Answers[q.Name].Choice}` at {o.Result!.Answers[q.Name].Top:0.00}, {secondModel} `{opinions[o.Item.Number].Choices[q.Name]}`"
                + (o.Expected?.GetValueOrDefault(q.Name) is { } label ? $", label `{label}`" : "")))
        .ToList();
    report.AppendLine($"Same option for every question: {asked.Count(o => o.Questions.All(q => opinions[o.Item.Number].Choices[q.Name] == o.Result!.Answers[q.Name].Choice))} of {asked.Count} pay items.").AppendLine();

    Settlement Settle(Outcome o, double t) =>
        EscalationPolicy.Settle(ReviewPolicy.Evaluate(o.Item, o.Result!, o.Questions, t), o.Result!, o.Questions, t, opinions.GetValueOrDefault(o.Item.Number), false, secondModel);
    if (dataset == "labeled")
    {
        report.AppendLine("| Threshold | Accepted by rule | Accepted by agreement | Accepted without review | Wrong among accepted | Sent to people | Wrong lines caught by people |").AppendLine("| ---: | ---: | ---: | ---: | ---: | ---: | ---: |");
        foreach (var t in thresholds)
        {
            var lines = ok.Select(o => (Route: Settle(o, t).Route, Wrong: o.Expected!.Any(e => o.Result!.Answers[e.Key].Choice != e.Value))).ToList();
            var (rule, agreed) = (lines.Count(l => l.Route == LineRoute.Rule), lines.Count(l => l.Route == LineRoute.Agreement));
            var people = lines.Where(l => l.Route == LineRoute.Person).ToList();
            report.AppendLine($"| {t:0.00} | {rule} | {agreed} | {rule + agreed} of {lines.Count} ({Percent(rule + agreed, lines.Count)}) | {lines.Count(l => l.Route != LineRoute.Person && l.Wrong)} | {people.Count} | {people.Count(l => l.Wrong)} of {lines.Count(l => l.Wrong)} |");
        }
        report.AppendLine();
        var agreedWrong = ok.Where(o => Settle(o, ReviewPolicy.MaxThreshold).Route == LineRoute.Agreement && o.Expected!.Any(e => o.Result!.Answers[e.Key].Choice != e.Value))
            .Select(o => $"- {o.Item.Number} `{o.Item.Description}` — " + string.Join("; ", o.Expected!.Where(e => o.Result!.Answers[e.Key].Choice != e.Value).Select(e => $"{e.Key}: both chose `{o.Result!.Answers[e.Key].Choice}`, label `{e.Value}`")))
            .ToList();
        report.AppendLine(agreedWrong.Count == 0
            ? "No labeled line was accepted by agreement with an answer that differs from its label, at any threshold in the table."
            : "### Lines where both models agreed on an answer that differs from the label").AppendLine();
        if (agreedWrong.Count > 0) { agreedWrong.ForEach(w => report.AppendLine(w)); report.AppendLine(); }
    }
    else
    {
        report.AppendLine("| Threshold | Accepted by rule | Accepted by agreement | Sent to people | Amount with people |").AppendLine("| ---: | ---: | ---: | ---: | ---: |");
        foreach (var t in thresholds)
        {
            var lines = ok.Select(o => (o.Item, Settle(o, t).Route)).ToList();
            var people = lines.Where(l => l.Route == LineRoute.Person).ToList();
            report.AppendLine($"| {t:0.00} | {lines.Count(l => l.Route == LineRoute.Rule)} | {lines.Count(l => l.Route == LineRoute.Agreement)} | {people.Count} | {Usd(people.Sum(l => l.Item.Amount))} |");
        }
        report.AppendLine();
    }
    if (disagreements.Count > 0)
    {
        report.AppendLine("### Answers where the models disagree").AppendLine();
        disagreements.ForEach(d => report.AppendLine(d));
        report.AppendLine();
    }
    var secondLatencies = opinions.Values.Select(o => o.ElapsedMs).ToList();
    var (inTokens, outTokens) = (opinions.Values.Sum(o => o.InputTokens ?? 0), opinions.Values.Sum(o => o.OutputTokens ?? 0));
    report.AppendLine($"- {secondModel} round trip per pay item{(escalationMode == "replay" ? " (recorded)" : "")}: p50 {Scoring.Percentile(secondLatencies, 50):0} ms, p95 {Scoring.Percentile(secondLatencies, 95):0} ms, max {(secondLatencies.Count == 0 ? 0 : secondLatencies.Max())} ms.");
    var secondCost = EscalationPricing.Estimate(secondModel, inTokens, outTokens);
    report.AppendLine($"- Tokens: {inTokens} input and {outTokens} output, including reasoning tokens. "
        + (secondCost is { } c ? $"{(escalationMode == "replay" ? "Estimated cost when recorded" : "Estimated cost")}: ${c:0.000000} ({EscalationPricing.Source})" : $"No list price for {secondModel} is recorded in this sample."));
    report.AppendLine();
}

if (reversed is not null)
{
    report.AppendLine("## Option-order robustness").AppendLine();
    var pairs = forward.Zip(reversed).Where(p => p.First.Result is not null && p.Second.Result is not null).ToList();
    var answers = pairs.Sum(p => p.First.Questions.Count);
    var flips = pairs.SelectMany(p => p.First.Questions.Where(q => p.First.Result!.Answers[q.Name].Choice != p.Second.Result!.Answers[q.Name].Choice)
        .Select(q => $"{p.First.Item.Number} {q.Name}: {p.First.Result!.Answers[q.Name].Choice} → {p.Second.Result!.Answers[q.Name].Choice}")).ToList();
    report.AppendLine($"Answers that changed when every option list was reversed: {flips.Count} of {answers}.");
    foreach (var flip in flips.Take(20)) report.AppendLine($"- {flip}");
    report.AppendLine();
}

report.AppendLine("## Latency and cost").AppendLine();
{
    var latencies = ok.Select(o => o.Result!.ElapsedMs).ToList();
    var tokens = ok.Where(o => o.Result!.InputTokens is not null).Select(o => o.Result!.InputTokens!.Value).ToList();
    // Every request in the run is billed, including the reversed-order pass.
    var allTokens = forward.Concat(reversed ?? []).Where(o => o.Result?.InputTokens is not null).Sum(o => o.Result!.InputTokens!.Value);
    report.AppendLine($"- HTTP round trip per pay item{(mode == "replay" ? " (recorded)" : "")}: p50 {Scoring.Percentile(latencies, 50):0} ms, p95 {Scoring.Percentile(latencies, 95):0} ms, max {(latencies.Count == 0 ? 0 : latencies.Max())} ms. Measured from this machine; includes network time.");
    report.AppendLine(tokens.Count == 0
        ? "- Input tokens: not reported in responses."
        : $"- Input tokens: {tokens.Sum()} in the original-order pass ({tokens.Average():0} per pay item); {allTokens} for all requests in this run. {(mode == "replay" ? "Estimated cost when recorded" : "Estimated cost of this run")}: ${Pricing.Estimate(allTokens):0.000000} ({Pricing.Source}){(mode == "replay" ? " This replay made no new requests." : "")}");
}
report.AppendLine();

if (errors.Count > 0 || secondErrors.Count > 0)
{
    report.AppendLine("## Failed requests").AppendLine();
    foreach (var group in errors.Select(e => e.Error!).Concat(secondErrors.Select(e => $"Second model: {e}")).GroupBy(e => e)) report.AppendLine($"- {group.Count()} × {group.Key}");
    report.AppendLine();
}

report.AppendLine("## Limits of this evaluation").AppendLine();
report.AppendLine("- Synthetic pay items and labels written for this sample; results do not transfer to other documents or tasks without measuring them.");
report.AppendLine("- One run. No confidence intervals. Small question groups make percentages noisy.");
report.AppendLine("- Decisions are support for an estimator's review, not a substitute for it.");

var text = report.ToString();
var outPath = options.GetValueOrDefault("out", Path.Combine("artifacts", "bid-review-queue", $"{started:yyyyMMdd-HHmmss}-{mode}-{dataset}.md"));
Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outPath))!);
File.WriteAllText(outPath, text, new UTF8Encoding(false));
Console.WriteLine(text);
Console.WriteLine($"Report written to {outPath}");
return errors.Count == 0 && secondErrors.Count == 0 ? 0 : 1;

static string Percent(int part, int whole) => whole == 0 ? "n/a" : $"{100.0 * part / whole:0.0}%";
static string Usd(decimal amount) => amount.ToString("C0", CultureInfo.GetCultureInfo("en-US"));

record Outcome(BidItem Item, IReadOnlyDictionary<string, string>? Expected, IReadOnlyList<ChoiceQuestion> Questions, DecisionResult? Result, string? Error);
