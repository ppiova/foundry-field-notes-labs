using System.Net;
using System.Text.Json.Nodes;
using Azure.Core;
using Azure.Identity;
using BidReviewQueue;

int passed = 0;
void Check(bool condition, string label)
{
    if (!condition) throw new Exception($"FAIL {label}");
    Console.WriteLine($"PASS {label}");
    passed++;
}
void Reject(Action action, string label)
{
    try { action(); }
    catch (InvalidDataException) { Console.WriteLine($"PASS {label}"); passed++; return; }
    throw new Exception($"FAIL {label}");
}

// User-supplied JSON must fail as a recoverable validation error, including valid scalar JSON.
foreach (var invalid in new[] { "42", "true", "\"hello\"", "null", "{}", "[]", "{\"items\":[42]}" })
    Reject(() => BidFormReader.Parse(invalid, "test.json"), $"Reject unsupported bid form shape: {invalid}");
const string uploadedItem = """{"number":"1","description":"Mobilization","unit":"LS","quantity":1,"unitPrice":100}""";
Check(BidFormReader.Parse($"[{uploadedItem}]", "test.json").Items.Single().Amount == 100, "A root array loads a valid pay item");
Check(BidFormReader.Parse($"{{\"title\":\"Example\",\"items\":[{uploadedItem}]}}", "test.json").Title == "Example", "A bid form object preserves its title");
Reject(() => BidFormReader.Parse($"[{uploadedItem},{uploadedItem}]", "test.json"), "Duplicate pay item numbers are rejected");

// Options come from the application: fixed taxonomies plus spans copied from the description.
const string sewer = "8\" PVC SDR-26 Gravity Sanitary Sewer, 6'-8' Depth, Furnish and Install";
var questions = PayItemQuestions.For(sewer);
Check(questions.Select(q => q.Name).SequenceEqual(["system", "work_type", "diameter", "material", "depth_band"]), "Span questions are asked only when the description has spans");
Check(questions.Single(q => q.Name == "depth_band").Options.Select(o => o.Key).SequenceEqual(["6'-8'", PayItemQuestions.None]), "A span question offers the copied spans plus none");
Check(PayItemQuestions.For("Mobilization").Count == 2, "A description without spans gets only the taxonomy questions");
Check(PayItemQuestions.Candidates(PayItemQuestions.Diameter(), "6\" PVC Lateral, Connection to 8\" Main").SequenceEqual(["6\"", "8\""]), "Every size span becomes an option");
Check(PayItemQuestions.Candidates(PayItemQuestions.Diameter(), "Furnish 5/8\" x 3/4\" Water Meters").Count == 0, "Fractions are not split into false sizes");
Check(PayItemQuestions.Candidates(PayItemQuestions.DepthBand(), "Tree Removal, 12\" to 24\" Diameter").Count == 0, "Inch ranges are not depth bands");
Check(PayItemQuestions.Candidates(PayItemQuestions.Material(), "6\" PVC (C-900) Force Main").SequenceEqual(["PVC (C-900)"]), "A material span keeps its class");

// Labels must name options the application actually offers, or the evaluation would be meaningless.
var labeled = DataSets.Labeled.Items;
var misaligned = labeled.Where(item =>
{
    var asked = PayItemQuestions.For(item.Description).ToDictionary(q => q.Name);
    return !asked.Keys.ToHashSet().SetEquals(item.Expected.Keys)
        || item.Expected.Any(e => !asked[e.Key].Options.Any(o => o.Key == e.Value));
}).Select(i => i.Number).ToList();
Check(misaligned.Count == 0, $"All {labeled.Count} labeled items match the questions and options the application builds{(misaligned.Count > 0 ? ": " + string.Join(", ", misaligned) : "")}");
Check(labeled.Select(i => i.Description).Distinct().Count() == labeled.Count, "Labeled descriptions are unique");
Check(DataSets.Demo.Items.All(i => i.Validate() is null) && DataSets.Demo.Items.Count >= 30, "The demo bid form has at least 30 valid pay items");

// Request shape follows the Microsoft Learn article: model, state, and typed questions with instructions and criteria.
var item = new BidItem("5", sewer, "LF", 1365, 142);
var request = DecisionWire.BuildRequest("example-decision", item.ToState(), questions, reverseOptions: false);
Check((string?)request["model"] == "example-decision" && (string?)request["questions"]!["system"]!["type"] == "choice"
    && request["questions"]!["system"]!["criteria"] is JsonObject && request["questions"]!["system"]!["instructions"] is not null, "The request uses model, state and typed choice questions");
var stateKeys = request["state"]!.AsObject().Select(p => p.Key).ToList();
Check(stateKeys.SequenceEqual(["pay_item", "description", "unit"]), "Quantities and prices stay in the application");
var reversed = DecisionWire.BuildRequest("example-decision", item.ToState(), questions, reverseOptions: true);
Check(reversed["questions"]!["system"]!["criteria"]!.AsObject().First().Key == PayItemQuestions.Systems[^1].Key, "Reversing reverses every option list");

// Response contract: an answer must choose an offered option and score every offered option.
string Response(Action<JsonObject>? change = null)
{
    var answers = new JsonObject();
    foreach (var q in questions)
    {
        var probabilities = new JsonObject();
        var first = q.Options[0].Key;
        foreach (var o in q.Options) probabilities[o.Key] = o.Key == first ? 0.9 : 0.1 / (q.Options.Count - 1);
        answers[q.Name] = new JsonObject { ["type"] = "choice", ["choice"] = first, ["probabilities"] = probabilities };
    }
    var body = new JsonObject { ["model"] = "microsoft-decision-1", ["answers"] = answers, ["usage"] = new JsonObject { ["input_tokens"] = 190 } };
    change?.Invoke(body);
    return body.ToJsonString();
}
var valid = DecisionWire.ParseResponse(Response(), questions, 12);
Check(valid.Answers["system"].Choice == "sanitary_gravity" && valid.InputTokens == 190 && valid.Model == "microsoft-decision-1", "A valid response is accepted");
Check(Math.Abs(valid.Answers["system"].Top - 0.9) < 1e-9 && valid.Answers["system"].Margin > 0.8, "Top probability and margin are computed from the response");
Reject(() => DecisionWire.ParseResponse(Response(b => b["answers"]!["system"]!["choice"] = "drainage"), questions, 0), "Reject an option that was not offered");
Reject(() => DecisionWire.ParseResponse(Response(b => b["answers"]!.AsObject().Remove("work_type")), questions, 0), "Reject a missing answer");
Reject(() => DecisionWire.ParseResponse(Response(b => b["answers"]!["system"]!.AsObject().Remove("probabilities")), questions, 0), "Reject an answer without probabilities");
Reject(() => DecisionWire.ParseResponse(Response(b => b["answers"]!["system"]!["probabilities"]!["water"] = 1.5), questions, 0), "Reject a probability above 1");
Reject(() => DecisionWire.ParseResponse(Response(b => b["answers"]!["system"]!["probabilities"]!["drainage"] = 0), questions, 0), "Reject a probability for an option that was not offered");
Reject(() => DecisionWire.ParseResponse(Response(b => b["answers"]!["system"]!["probabilities"]!.AsObject().Remove("water")), questions, 0), "Reject probabilities that skip an option");
Reject(() => DecisionWire.ParseResponse(Response(b => b["answers"]!["system"]!["probabilities"]!["sanitary_gravity"] = 0.5), questions, 0), "Reject probabilities that do not sum to 1");
Reject(() => DecisionWire.ParseResponse(Response(b => b["answers"]!["system"]!["type"] = "noul"), questions, 0), "Reject an answer of the wrong type");
Reject(() => DecisionWire.ParseResponse(Response(b => b["answers"]!["system"]!["probabilities"]!["water"] = "0.1"), questions, 0), "Reject a probability that is not a number");
Reject(() => DecisionWire.ParseResponse("not JSON", questions, 0), "Reject malformed JSON");
Reject(() => DecisionWire.ParseResponse("null", questions, 0), "Reject a null response");
Reject(() => DecisionWire.ParseResponse("""{"answers":[]}""", questions, 0), "Reject answers that are not an object");

// Review policy: thresholds, abstention, and review priority score.
var allowance = new BidItem("34", "Owner's Contingency Allowance", "LS", 1, 250_000);
var two = PayItemQuestions.For(allowance.Description);
DecisionResult Result(double system, double work, string workChoice = "general_conditions") => new(new Dictionary<string, ChoiceAnswer>
{
    ["system"] = new("general", PayItemQuestions.Systems.ToDictionary(o => o.Key, o => o.Key == "general" ? system : (1 - system) / 5)),
    ["work_type"] = new(workChoice, PayItemQuestions.WorkTypes.ToDictionary(o => o.Key, o => o.Key == workChoice ? work : (1 - work) / 8)),
}, 100, "microsoft-decision-1", 10);
var review = ReviewPolicy.Evaluate(allowance, Result(0.98, 0.88), two, 0.90);
Check(!review.AutoAccept && review.Reasons.Single() == "Work type: 0.88 is below 0.90", "An answer below the threshold sends the line to review");
Check(review.PriorityScore == 30_000m && Math.Abs(review.Confidence - 0.88) < 1e-9, "The review priority score uses the weakest answer");
Check(ReviewPolicy.Evaluate(allowance, Result(0.98, 0.88), two, 0.85).AutoAccept, "A lower threshold accepts the same line");
Check(!ReviewPolicy.Evaluate(allowance, Result(0.99, 0.99), two, 0.50, hasReviewerEdits: true).AutoAccept, "Reviewer edits cannot inherit automatic acceptance even at a lower threshold");
Check(!ReviewPolicy.Evaluate(allowance, Result(0.99, 0.99, PayItemQuestions.Unclear), two, 0.50).AutoAccept, "An unclear answer always needs review");
var notTop = new DecisionResult(new Dictionary<string, ChoiceAnswer>
{
    ["system"] = new("general", PayItemQuestions.Systems.ToDictionary(o => o.Key, o => o.Key switch { "general" => 0.3, "water" => 0.6, _ => 0.025 })),
    ["work_type"] = Result(0.99, 0.99).Answers["work_type"],
}, null, "x", 0);
Check(ReviewPolicy.Evaluate(allowance, notTop, two, 0.20).Reasons.Single().Contains("not the most probable"), "A selected option that is not the most probable needs review");

// The recordings shipped with the sample cover their datasets in both option orders and still pass the contract,
// so a change to the questions cannot silently leave the recorded engine stale.
var bundledDemo = ReplayProvider.LoadBundled(ReplayProvider.DemoRecording);
var bundledLabeled = ReplayProvider.LoadBundled(ReplayProvider.LabeledRecording);
async Task<int> Replayable(ReplayProvider replay, IEnumerable<BidItem> items)
{
    var decided = 0;
    foreach (var bidItem in items)
        foreach (var reverse in new[] { false, true })
        {
            await replay.DecideAsync(bidItem.ToState(), PayItemQuestions.For(bidItem.Description), reverse, CancellationToken.None);
            decided++;
        }
    return decided;
}
Check(await Replayable(bundledDemo, DataSets.Demo.Items) == DataSets.Demo.Items.Count * 2, "The bundled demo recording covers every demo pay item in both orders and passes the contract");
Check(await Replayable(bundledLabeled, DataSets.Labeled.Items.Select(i => i.ToItem())) == DataSets.Labeled.Items.Count * 2, "The bundled labeled recording covers every labeled item in both orders and passes the contract");
var demoSewer = DataSets.Demo.Items.Single(i => i.Number == "4");
var recordedSewer = await bundledDemo.DecideAsync(demoSewer.ToState(), PayItemQuestions.For(demoSewer.Description), false, CancellationToken.None);
Check(recordedSewer.Model == "microsoft-decision-1" && recordedSewer.InputTokens > 0 && recordedSewer.Answers["system"].Choice == "sanitary_gravity", "Recorded answers are real model responses with token usage");
// Settings never enable the live path with an unusable endpoint.
Check(!DecisionSettings.From(null, null).Configured, "Live path is off without configuration");
Check(DecisionSettings.From("https://example.services.ai.azure.com/api/projects/example", "example-decision").Problem!.Contains("project endpoint"), "A project endpoint is rejected with guidance");
Check(!DecisionSettings.From("http://example.services.ai.azure.com", "example-decision").Configured, "A non-https endpoint is rejected");
Check(!DecisionSettings.From("https://example.services.ai.azure.com", "bad name!").Configured, "An invalid deployment name is rejected");
var configured = DecisionSettings.From("https://example.services.ai.azure.com/providers/microsoft/v1/systemone", " example-decision ");
var provider = new FoundryDecisionProvider(new HttpClient(), configured, new AzureCliCredential());
Check(configured.Configured && provider.RequestUri.ToString() == "https://example.services.ai.azure.com/providers/microsoft/v1/systemone" && provider.Deployment == "example-decision", "The decision URL is built from the resource endpoint");

Check(Credentials.Create(null) is AzureCliCredential && Credentials.Create("managed-identity") is ManagedIdentityCredential, "Azure CLI locally, the managed identity in Azure");
try { Credentials.Create("default"); Check(false, "Unknown credential mode"); }
catch (InvalidOperationException) { Check(true, "An unknown credential mode is rejected instead of falling back to a chain"); }

// The live client, exercised against a local stub: no network and no Azure calls.
var credential = new FakeCredential();
var calls = 0;
var stub = new StubHandler((request, body) => ++calls == 1
    ? new HttpResponseMessage(HttpStatusCode.TooManyRequests) { Headers = { { "retry-after-ms", "1" } } }
    : new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(Response()) });
var live = new FoundryDecisionProvider(new HttpClient(stub), configured, credential);
var liveResult = await live.DecideAsync(item.ToState(), questions, false, CancellationToken.None);
var sent = stub.Requests[^1];
Check(stub.Requests.Count == 2 && liveResult.Answers["system"].Choice == "sanitary_gravity", "One retry after HTTP 429, then the response is validated");
Check(sent.Request.Headers.Authorization?.ToString() == "Bearer fake-token" && sent.ContentLength > 0
    && (string?)JsonNode.Parse(sent.Body)!["model"] == "example-decision", "Requests carry a bearer token, a Content-Length and the deployment name");
Check(liveResult.Request is { Rebuilt: false } liveRequest && liveRequest.Body == sent.Body && liveResult.RawResponse == Response(), "A live result keeps the exact request body it sent and the response it received");
await live.DecideAsync(item.ToState(), questions, false, CancellationToken.None);
Check(credential.Calls == 1, "The token is cached between requests");
var denied = new FoundryDecisionProvider(new HttpClient(new StubHandler((_, _) => new HttpResponseMessage(HttpStatusCode.Unauthorized))), configured, credential);
try { await denied.DecideAsync(item.ToState(), questions, false, CancellationToken.None); Check(false, "HTTP 401 is an error"); }
catch (DecisionApiException ex) { Check(ex.Status == HttpStatusCode.Unauthorized && ex.Message.Contains("az login"), "HTTP 401 is an error with guidance and no retry"); }
var garbled = new FoundryDecisionProvider(new HttpClient(new StubHandler((_, _) => new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("""{"answers":{}}""") })), configured, credential);
try { await garbled.DecideAsync(item.ToState(), questions, false, CancellationToken.None); Check(false, "An incomplete response is an error"); }
catch (InvalidDataException) { Check(true, "An incomplete live response is an error, not a fallback"); }

// Replay re-validates recorded responses and never invents a missing one.
var recordingPath = Path.Combine(Path.GetTempPath(), $"bid-review-replay-{Guid.NewGuid():N}.jsonl");
File.WriteAllText(recordingPath, ReplayProvider.Serialize(new Recording(DateTimeOffset.UtcNow, "example-decision", "microsoft-decision-1", false, sewer, "LF", 231, Response())) + "\n");
try
{
    var replay = ReplayProvider.Load(recordingPath)!;
    var replayed = await replay.DecideAsync(item.ToState(), questions, false, CancellationToken.None);
    Check(replayed.ElapsedMs == 231 && replayed.Answers.Count == questions.Count, "Replay serves a recorded response with its recorded latency");
    try { await replay.DecideAsync(allowance.ToState(), two, false, CancellationToken.None); Check(false, "Replay miss"); }
    catch (ReplayMissException) { Check(true, "Replay reports a missing recording instead of inventing one"); }
}
finally { File.Delete(recordingPath); }

// The service shared by the API and the Blazor UI never substitutes another source for a missing one.
var service = new DecisionService(DecisionSettings.From(null, null), null, bundledDemo, Microsoft.Extensions.Logging.Abstractions.NullLogger<DecisionService>.Instance);
async Task<int?> FailureStatus(BidItem target, string? mode)
{
    try { await service.DecideAsync(target, mode, false, CancellationToken.None); return null; }
    catch (DecisionFailure failure) { return failure.StatusCode; }
}
Check(await FailureStatus(item, "foundry") == 503, "An unconfigured live source fails with 503 instead of using another source");
Check(await FailureStatus(item, "simulation") == 400 && await FailureStatus(item, "other") == 400 && await FailureStatus(item with { Description = "" }, "replay") == 400, "Removed or unknown modes and invalid items fail with 400");
Check(await FailureStatus(allowance with { Description = "Not in the recording" }, "replay") == 404, "A pay item missing from the recording fails with 404 instead of an invented answer");
Check((await service.DecideAsync(DataSets.Demo.Items.Single(i => i.Number == "34"), "replay", false, CancellationToken.None)).Mode == "replay", "The recorded engine is labeled by the service");

// Second opinion: the same closed questions as a strict JSON schema, so the second model can only return offered options.
var secondRequest = SecondOpinionWire.BuildRequest("example-escalation", item.ToState(), questions);
var schema = secondRequest["text"]!["format"]!;
var enums = schema["schema"]!["properties"]!.AsObject().ToDictionary(p => p.Key, p => p.Value!["enum"]!.AsArray().Select(v => (string)v!).ToList());
Check((bool?)secondRequest["store"] == false && (string?)secondRequest["reasoning"]!["effort"] == "low", "Second-opinion requests are stateless and use low reasoning effort");
Check((string?)secondRequest["model"] == "example-escalation" && (string?)schema["type"] == "json_schema" && (bool?)schema["strict"] == true
    && (bool?)schema["schema"]!["additionalProperties"] == false && schema["schema"]!["required"]!.AsArray().Count == questions.Count, "The second-opinion request is a strict JSON schema that requires every question");
Check(enums.Keys.SequenceEqual(questions.Select(q => q.Name)) && questions.All(q => enums[q.Name].Count == q.Options.Count), "Every question offers exactly the application's options");
Check(enums["system"].SequenceEqual(PayItemQuestions.Systems.Select(o => o.Key)) && enums["diameter"].SequenceEqual(["option_1", PayItemQuestions.None]), "Taxonomy keys stay as they are; quoted spans travel under aliases");
Check(enums.Values.SelectMany(v => v).All(v => !v.Contains('"')), "No enum value contains a double quote, which strict mode rejected in our tests");
var secondInput = (string)secondRequest["input"]!;
Check(secondInput.Contains("8\\\" PVC SDR-26") && secondInput.Contains("\"unit\":\"LF\"") && !secondInput.Contains("1365") && !secondInput.Contains("142"), "The second model sees the description and unit, not quantities or prices");
string SecondResponse(Action<JsonObject>? change = null, string? text = null)
{
    var answer = new JsonObject();
    foreach (var q in questions) answer[q.Name] = SecondOpinionWire.Alias(q, 0);
    var body = new JsonObject
    {
        ["status"] = "completed",
        ["model"] = "example-escalation",
        ["output"] = new JsonArray(
            new JsonObject { ["type"] = "reasoning", ["summary"] = new JsonArray() },
            new JsonObject { ["type"] = "message", ["content"] = new JsonArray(new JsonObject { ["type"] = "output_text", ["text"] = text ?? answer.ToJsonString() }) }),
        ["usage"] = new JsonObject { ["input_tokens"] = 600, ["output_tokens"] = 40 },
    };
    change?.Invoke(body);
    return body.ToJsonString();
}
var opinion = SecondOpinionWire.ParseResponse(SecondResponse(), questions, "gpt-6-luna", 900);
Check(opinion.Choices["diameter"] == "8\"" && opinion.Choices["system"] == "sanitary_gravity" && opinion.InputTokens == 600 && opinion.OutputTokens == 40 && opinion.Model == "gpt-6-luna", "A valid second opinion is mapped back to the application's keys");
Reject(() => SecondOpinionWire.ParseResponse(SecondResponse(b => b["status"] = "incomplete"), questions, "m", 0), "Reject an incomplete second opinion");
Reject(() => SecondOpinionWire.ParseResponse(SecondResponse(b => b["output"]![1]!["content"]![0]!["type"] = "refusal"), questions, "m", 0), "Reject a refusal");
Reject(() => SecondOpinionWire.ParseResponse(SecondResponse(text: """{"system":"drainage","work_type":"furnish_install","diameter":"option_1","material":"option_1","depth_band":"option_1"}"""), questions, "m", 0), "Reject a second opinion that chooses an option that was not offered");
Reject(() => SecondOpinionWire.ParseResponse(SecondResponse(text: """{"system":"sanitary_gravity"}"""), questions, "m", 0), "Reject a second opinion with a missing answer");
Reject(() => SecondOpinionWire.ParseResponse(SecondResponse(text: "8 inch"), questions, "m", 0), "Reject a second opinion that is not JSON");
Reject(() => SecondOpinionWire.ParseResponse(SecondResponse(b =>
{
    var part = b["output"]![1]!["content"]![0]!;
    var extended = JsonNode.Parse((string)part["text"]!)!.AsObject();
    extended["rationale"] = "extra";
    part["text"] = extended.ToJsonString();
}), questions, "m", 0), "Reject a second opinion with an extra field");
Reject(() => SecondOpinionWire.ParseResponse("not JSON", questions, "m", 0), "Reject a malformed second-opinion response");

// Escalation policy: only lines below the threshold with no abstention can be settled by agreement.
var agreeing = new SecondOpinion(new Dictionary<string, string> { ["system"] = "general", ["work_type"] = "general_conditions" }, "gpt-6-luna", 1, 1, 1);
var differing = agreeing with { Choices = new Dictionary<string, string> { ["system"] = "general", ["work_type"] = "support_work" } };
Settlement Settle(DecisionResult result, double threshold, SecondOpinion? second, bool edited = false) =>
    EscalationPolicy.Settle(ReviewPolicy.Evaluate(allowance, result, two, threshold, edited), result, two, threshold, second, edited, "gpt-6-luna");
Check(Settle(Result(0.98, 0.95), 0.90, null).Route == LineRoute.Rule, "Lines above the threshold are accepted by the rule without a second model");
Check(Settle(Result(0.98, 0.88), 0.90, agreeing) is { Route: LineRoute.Agreement, Differences.Count: 0 }, "A line below the threshold is accepted when both models choose the same answers");
Check(Settle(Result(0.98, 0.88), 0.90, differing) is { Route: LineRoute.Person } s && s.Differences.Single().Contains("Support work"), "Any disagreement sends the line to a person with both answers");
Check(Settle(Result(0.98, 0.88), 0.90, null) is { Route: LineRoute.Person } m && m.Note!.Contains("No second opinion"), "Without a second opinion the line stays with a person");
var unclearResult = Result(0.98, 0.88, PayItemQuestions.Unclear);
Check(Settle(unclearResult, 0.90, agreeing with { Choices = new Dictionary<string, string> { ["system"] = "general", ["work_type"] = PayItemQuestions.Unclear } }).Route == LineRoute.Person, "An Unclear answer goes to a person even when the second model agrees");
Check(Settle(Result(0.98, 0.88), 0.90, agreeing, edited: true).Route == LineRoute.Person, "Reviewer edits go to a person even when the models agree");
Check(Settle(Result(0.98, 0.88), 0.90, differing, edited: true).Differences.Count == 0 && Settle(Result(0.98, 0.88), 0.80, differing).Route == LineRoute.Rule
    && EscalationPolicy.Differences(Result(0.98, 0.88), two, differing, "gpt-6-luna").Single().Contains("Support work")
    && EscalationPolicy.Differences(Result(0.98, 0.88), two, agreeing, "gpt-6-luna").Count == 0, "A disagreement stays visible after an edit or when the rule accepts the line");
Check(Settle(notTop, 0.90, new SecondOpinion(new Dictionary<string, string> { ["system"] = "general", ["work_type"] = "general_conditions" }, "m", 1, 1, 1)).Route == LineRoute.Person, "A selected option that is not the most probable goes to a person even when the models agree");
Check(!EscalationPolicy.Eligible(Result(0.98, 0.95), two, 0.90) && EscalationPolicy.Eligible(Result(0.98, 0.95), two, 0.99), "Eligibility follows the threshold");

// Second-model settings and client, against a local stub.
Check(!EscalationSettings.From(null, null).Configured && !EscalationSettings.From("bad name!", null).Configured, "The second model is off without a valid deployment name");
Check(EscalationSettings.From(" example-escalation ", null) is { Configured: true, Deployment: "example-escalation", ModelName: "example-escalation" }
    && EscalationSettings.From("example-escalation", "gpt-6-luna").ModelName == "gpt-6-luna", "The display label defaults to the deployment name");
var escalationSettings = EscalationSettings.From("example-escalation", "gpt-6-luna");
var secondCredential = new FakeCredential();
var secondCalls = 0;
var secondStub = new StubHandler((_, _) => ++secondCalls == 1
    ? new HttpResponseMessage(HttpStatusCode.RequestTimeout)
    : new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(SecondResponse()) });
var secondLive = new FoundrySecondOpinionProvider(new HttpClient(secondStub), configured.Endpoint!, escalationSettings, secondCredential);
var secondResult = await secondLive.AskAsync(item.ToState(), questions, CancellationToken.None);
var secondSent = secondStub.Requests[^1];
Check(secondLive.RequestUri.ToString() == "https://example.services.ai.azure.com/openai/v1/responses" && secondStub.Requests.Count == 2 && secondResult.Choices["diameter"] == "8\"", "The second model uses the v1 Responses API, with one retry after HTTP 408");
Check(secondSent.Request.Headers.Authorization?.ToString() == "Bearer fake-token" && secondCredential.Scopes.Single() == "https://ai.azure.com/.default"
    && (string?)JsonNode.Parse(secondSent.Body)!["model"] == "example-escalation", "Second-model requests carry a Microsoft Entra token for the documented scope and the deployment name");
Check(secondResult.Request is { Rebuilt: false } secondRequestKept && secondRequestKept.Body == secondSent.Body, "A live second opinion keeps the exact request body it sent");
var slowCalls = 0;
var slow = new FoundrySecondOpinionProvider(new HttpClient(new StubHandler((_, _) => new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(SecondResponse()) }) { Delay = () => ++slowCalls == 1 ? TimeSpan.FromSeconds(5) : TimeSpan.Zero }),
    configured.Endpoint!, escalationSettings, secondCredential) { AttemptTimeout = TimeSpan.FromMilliseconds(100) };
var slowResult = await slow.AskAsync(item.ToState(), questions, CancellationToken.None);
Check(slowCalls == 2 && slowResult.ElapsedMs >= 100, "A slow first attempt is abandoned and retried once, and the reported latency includes it");
var serverErrorCalls = 0;
var serverError = new FoundrySecondOpinionProvider(new HttpClient(new StubHandler((_, _) => ++serverErrorCalls == 1
    ? new HttpResponseMessage(HttpStatusCode.NotImplemented)
    : new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(SecondResponse()) })), configured.Endpoint!, escalationSettings, secondCredential);
await serverError.AskAsync(item.ToState(), questions, CancellationToken.None);
Check(serverErrorCalls == 2, "Any 5xx response from the second model gets the single retry");
var forbidden = new FoundrySecondOpinionProvider(new HttpClient(new StubHandler((_, _) => new HttpResponseMessage(HttpStatusCode.Forbidden))), configured.Endpoint!, escalationSettings, secondCredential);
try { await forbidden.AskAsync(item.ToState(), questions, CancellationToken.None); Check(false, "HTTP 403 is an error"); }
catch (DecisionApiException ex) { Check(ex.Status == HttpStatusCode.Forbidden, "HTTP 403 from the second model is an error, not a fallback"); }

// The recorded second opinions cover every line that could need one at any threshold the UI allows, in either order.
async Task<int> MissingOpinions(ReplayProvider decisions, SecondOpinionReplay seconds, IEnumerable<BidItem> items)
{
    var missing = 0;
    foreach (var bidItem in items)
    {
        var asked = PayItemQuestions.For(bidItem.Description);
        foreach (var reverse in new[] { false, true })
        {
            var result = await decisions.DecideAsync(bidItem.ToState(), asked, reverse, CancellationToken.None);
            if (!EscalationPolicy.Eligible(result, asked, ReviewPolicy.MaxThreshold)) continue;
            try { await seconds.AskAsync(bidItem.ToState(), asked, CancellationToken.None); }
            catch (ReplayMissException) { missing++; }
        }
    }
    return missing;
}
var secondDemo = SecondOpinionReplay.LoadBundled(SecondOpinionReplay.DemoRecording);
var secondLabeled = SecondOpinionReplay.LoadBundled(SecondOpinionReplay.LabeledRecording);
Check(await MissingOpinions(bundledDemo, secondDemo, DataSets.Demo.Items) == 0, "The bundled demo second opinions cover every eligible demo line and pass the contract");
Check(await MissingOpinions(bundledLabeled, secondLabeled, DataSets.Labeled.Items.Select(i => i.ToItem())) == 0, "The bundled labeled second opinions cover every eligible labeled line and pass the contract");
var bypass = DataSets.Demo.Items.Single(i => i.Description.StartsWith("Sanitary Sewer Bypass Pumping"));
var recordedOpinion = await secondDemo.AskAsync(bypass.ToState(), PayItemQuestions.For(bypass.Description), CancellationToken.None);
Check(secondDemo.ModelName == "gpt-6-luna" && recordedOpinion.InputTokens > 0 && recordedOpinion.OutputTokens > 0, "Recorded second opinions are real gpt-6-luna responses with token usage");

// A recording keeps only the response, so replay rebuilds the request for the inspector and says so.
var bypassQuestions = PayItemQuestions.For(bypass.Description);
var recordedBypass = await bundledDemo.DecideAsync(bypass.ToState(), bypassQuestions, false, CancellationToken.None);
var rebuiltBypass = recordedBypass.Request is { Rebuilt: true } r1 ? JsonNode.Parse(r1.Body)! : null;
Check(rebuiltBypass is not null && (string?)rebuiltBypass["model"] == "bid-review-decision"
    && JsonNode.DeepEquals(rebuiltBypass, DecisionWire.BuildRequest("bid-review-decision", bypass.ToState(), bypassQuestions, false))
    && recordedBypass.RawResponse is not null, "A recorded decision is shown with its recorded response and a request rebuilt for the recorded deployment");
var reversedBypass = await bundledDemo.DecideAsync(bypass.ToState(), bypassQuestions, true, CancellationToken.None);
Check(reversedBypass.Request is { Rebuilt: true } r2 && JsonNode.Parse(r2.Body)!["questions"]!["system"]!["criteria"]!.AsObject().First().Key == PayItemQuestions.Systems[^1].Key,
    "A rebuilt request keeps the recorded option order");
Check(recordedOpinion.Request is { Rebuilt: true } r3 && JsonNode.DeepEquals(JsonNode.Parse(r3.Body),
    SecondOpinionWire.BuildRequest("bid-review-escalation", bypass.ToState(), bypassQuestions)), "A recorded second opinion is shown with a request rebuilt for the recorded deployment");

// The code walkthrough quotes source files and recorded JSON. Fail when either drifts, so the presenter guide stays true.
DirectoryInfo? RepositoryRoot(string start)
{
    var directory = new DirectoryInfo(start);
    while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "global.json"))) directory = directory.Parent;
    return directory;
}
var repositoryRoot = RepositoryRoot(AppContext.BaseDirectory) ?? RepositoryRoot(Environment.CurrentDirectory)
    ?? throw new Exception("FAIL The repository root (global.json) was not found from the build output or the current directory");
var sampleRoot = Path.Combine(repositoryRoot.FullName, "samples", "02-bid-review-queue");
var walkthrough = File.ReadAllText(Path.Combine(sampleRoot, "docs", "code-walkthrough.md")).Replace("\r\n", "\n");
var verified = 0;
foreach (System.Text.RegularExpressions.Match block in System.Text.RegularExpressions.Regex.Matches(walkthrough,
    @"<!-- verify: (?<kind>[a-z-]+) (?<arg>[^ ]+) -->\n```[a-z]*\n(?<body>.*?)\n```", System.Text.RegularExpressions.RegexOptions.Singleline))
{
    var (kind, arg, body) = (block.Groups["kind"].Value, block.Groups["arg"].Value, block.Groups["body"].Value);
    var label = $"Walkthrough {kind} {arg}";
    if (kind == "source")
    {
        var file = Path.Combine(sampleRoot, arg);
        Check(File.Exists(file) && WalkthroughCheck.ContainsExcerpt(File.ReadAllText(file), body), $"{label} matches the source file");
        verified++;
        continue;
    }
    var line = DataSets.Demo.Items.Single(i => i.Number == arg);
    var asked = PayItemQuestions.For(line.Description);
    bool matches;
    if (kind.StartsWith("decision-"))
    {
        var decision = await bundledDemo.DecideAsync(line.ToState(), asked, false, CancellationToken.None);
        var real = kind == "decision-request" ? decision.Request!.Body : decision.RawResponse!;
        matches = WalkthroughCheck.Matches(JsonNode.Parse(body), JsonNode.Parse(real), excerpt: false);
    }
    else
    {
        var second = await secondDemo.AskAsync(line.ToState(), asked, CancellationToken.None);
        var secondBody = JsonNode.Parse(second.Request!.Body)!;
        matches = kind switch
        {
            "second-opinion-request" => WalkthroughCheck.Matches(JsonNode.Parse(body), secondBody, excerpt: false),
            "second-opinion-input" => body == ((string)secondBody["input"]!).TrimEnd('\n'),
            "second-opinion-response" => WalkthroughCheck.Matches(JsonNode.Parse(body), JsonNode.Parse(second.RawResponse!), excerpt: true),
            _ => throw new Exception($"FAIL unknown walkthrough check '{kind}'"),
        };
    }
    Check(matches, $"{label} matches the bundled recording");
    verified++;
}
Check(verified >= 12, $"The code walkthrough has {verified} verified excerpts");

// The service never substitutes a second opinion that is not available.
var secondService = new DecisionService(DecisionSettings.From(null, null), null, bundledDemo, Microsoft.Extensions.Logging.Abstractions.NullLogger<DecisionService>.Instance, null, null, secondDemo);
async Task<int?> SecondFailureStatus(BidItem target, string? mode)
{
    try { await secondService.SecondOpinionAsync(target, PayItemQuestions.For(target.Description), mode, CancellationToken.None); return null; }
    catch (DecisionFailure failure) { return failure.StatusCode; }
}
Check(!secondService.SecondOpinionAvailable("foundry") && secondService.SecondOpinionAvailable("replay") && !service.SecondOpinionAvailable("replay"), "Second-opinion availability is reported per engine");
Check(await SecondFailureStatus(bypass, "foundry") == 503 && await SecondFailureStatus(bypass, "other") == 400 && await SecondFailureStatus(allowance with { Description = "Not in the recording" }, "replay") == 404, "A missing second model or recording fails explicitly");
Check((await secondService.SecondOpinionAsync(bypass, PayItemQuestions.For(bypass.Description), "replay", CancellationToken.None)).Choices.Count > 0, "The recorded engine serves recorded second opinions");
Check(EscalationPricing.Estimate("gpt-6-luna", 1_000_000, 1_000_000) == 0.66m && EscalationPricing.Estimate("another-model", 1, 1) is null, "Second-model cost is estimated only for the model whose list price is recorded");

// Scoring helpers used by the evaluation command.
var perfect = new ChoiceAnswer("a", new Dictionary<string, double> { ["a"] = 1, ["b"] = 0 });
var even = new ChoiceAnswer("a", new Dictionary<string, double> { ["a"] = 0.5, ["b"] = 0.5 });
Check(Scoring.Brier(perfect, "a") == 0 && Math.Abs(Scoring.Brier(even, "a") - 0.5) < 1e-9, "Brier score is 0 for a perfect answer and 0.5 for a coin flip");
var bins = Scoring.Reliability([(0.95, true), (0.97, false), (0.55, true)], [0.5, 0.9, 1.0]);
Check(bins[0].Count == 1 && bins[1].Count == 2 && Math.Abs(bins[1].Accuracy - 0.5) < 1e-9, "Reliability bins count answers and accuracy");
Check(Scoring.Percentile([1, 2, 3, 4], 50) == 2.5 && Pricing.Estimate(1_000_000) == 0.042m && Pricing.Estimate(null) is null, "Percentiles and cost estimates are computed");

Console.WriteLine($"{passed} checks passed. No model was called.");

static class WalkthroughCheck
{
    /// <summary>
    /// Whether every segment of a quoted excerpt appears in the source, in order. Segments are separated by lines that
    /// contain only <c>// ...</c>; each segment must match whole consecutive lines and may be indented less than in the file.
    /// </summary>
    public static bool ContainsExcerpt(string source, string excerpt)
    {
        var lines = source.Replace("\r\n", "\n").Split('\n');
        var segments = new List<List<string>> { new() };
        foreach (var line in excerpt.Split('\n'))
            if (line.Trim() == "// ...") segments.Add([]); else segments[^1].Add(line);
        var from = 0;
        foreach (var segment in segments.Where(s => s.Count > 0))
        {
            var at = Enumerable.Range(from, Math.Max(0, lines.Length - segment.Count - from + 1)).FirstOrDefault(i => SegmentAt(lines, i, segment), -1);
            if (at < 0) return false;
            from = at + segment.Count;
        }
        return segments.Any(s => s.Count > 0);
    }

    static bool SegmentAt(string[] lines, int start, List<string> segment)
    {
        static int Lead(string s) => s.Length - s.TrimStart().Length;
        var extra = Lead(lines[start]) - Lead(segment[0]);
        if (extra < 0 || segment[0].Trim().Length == 0) return false;
        var prefix = lines[start][..extra];
        return segment.Select((s, j) => s.Trim().Length == 0 ? lines[start + j].Trim().Length == 0 : lines[start + j].TrimEnd() == (prefix + s).TrimEnd()).All(ok => ok);
    }

    /// <summary>
    /// Compares quoted JSON with the real JSON. A quoted string "..." stands for any string. An excerpt may leave out
    /// object properties and array items; otherwise both must have the same properties and items.
    /// </summary>
    public static bool Matches(JsonNode? quoted, JsonNode? actual, bool excerpt) => (quoted, actual) switch
    {
        (null, null) => true,
        (JsonValue v, JsonValue) when v.TryGetValue<string>(out var s) && s == "..." && actual.GetValueKind() == System.Text.Json.JsonValueKind.String => true,
        (JsonObject q, JsonObject a) => (excerpt || q.Count == a.Count) && q.All(p => a.TryGetPropertyValue(p.Key, out var value) && Matches(p.Value, value, excerpt)),
        (JsonArray q, JsonArray a) => excerpt ? InOrder(q, a) : q.Count == a.Count && q.Zip(a).All(p => Matches(p.First, p.Second, excerpt)),
        (JsonValue, JsonValue) => JsonNode.DeepEquals(quoted, actual),
        _ => false,
    };

    static bool InOrder(JsonArray quoted, JsonArray actual)
    {
        var next = 0;
        foreach (var item in quoted)
        {
            while (next < actual.Count && !Matches(item, actual[next], excerpt: true)) next++;
            if (next++ >= actual.Count) return false;
        }
        return true;
    }
}

sealed class FakeCredential : TokenCredential
{
    public int Calls;
    public HashSet<string> Scopes { get; } = [];
    public override AccessToken GetToken(TokenRequestContext context, CancellationToken ct)
    {
        Calls++;
        Scopes.UnionWith(context.Scopes);
        return new AccessToken("fake-token", DateTimeOffset.UtcNow.AddHours(1));
    }
    public override ValueTask<AccessToken> GetTokenAsync(TokenRequestContext context, CancellationToken ct) => new(GetToken(context, ct));
}

sealed class StubHandler(Func<HttpRequestMessage, string, HttpResponseMessage> respond) : HttpMessageHandler
{
    public List<(HttpRequestMessage Request, string Body, long? ContentLength)> Requests { get; } = [];
    public Func<TimeSpan>? Delay { get; init; }
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        var body = request.Content is null ? "" : await request.Content.ReadAsStringAsync(ct);
        Requests.Add((request, body, request.Content?.Headers.ContentLength));
        if (Delay?.Invoke() is { } delay && delay > TimeSpan.Zero) await Task.Delay(delay, ct);
        return respond(request, body);
    }
}
