using System.Reflection;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace BidReviewQueue;

/// <summary>One live response saved by the evaluation command, so it can be shown again without calling Azure.</summary>
record Recording(DateTimeOffset RecordedAtUtc, string Deployment, string Model, bool ReverseOptions, string Description, string Unit, long ElapsedMs, string Response);

sealed class ReplayMissException(string message = "This pay item is not in the recorded run. Decide it with Microsoft-Decision-1, or record it with the evaluation command first.") : Exception(message);

/// <summary>
/// Serves recorded Microsoft-Decision-1 responses. Each one is validated again with the same contract as a live
/// response. Recorded latency is the latency measured when it was recorded, not a new measurement.
/// </summary>
sealed class ReplayProvider : IDecisionProvider
{
    /// <summary>Recordings shipped with the sample: the demo bid form and the labeled set, both orders.</summary>
    public const string DemoRecording = "demo-run.jsonl", LabeledRecording = "labeled-run.jsonl";

    internal static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);
    readonly Dictionary<(string, string, bool), Recording> recordings;

    ReplayProvider(IReadOnlyList<Recording> all)
    {
        recordings = all.GroupBy(r => (r.Description, r.Unit, r.ReverseOptions)).ToDictionary(g => g.Key, g => g.Last());
        // Describe the responses that will actually be served, not the first line of the file.
        var served = recordings.Values.ToList();
        var deployments = string.Join(", ", served.Select(r => $"'{r.Deployment}'").Distinct());
        var (from, to) = (served.Min(r => r.RecordedAtUtc), served.Max(r => r.RecordedAtUtc));
        var dates = from.Date == to.Date ? $"{from:yyyy-MM-dd}" : $"{from:yyyy-MM-dd} to {to:yyyy-MM-dd}";
        Summary = $"{recordings.Count} recorded responses from deployment {deployments}, recorded {dates} UTC";
    }

    public string Mode => "replay";
    public string Summary { get; }

    /// <summary>Loads a recording file, or returns null when no path is configured.</summary>
    public static ReplayProvider? Load(string? path) =>
        string.IsNullOrWhiteSpace(path) ? null : Parse(File.ReadLines(path), path);

    /// <summary>Loads a recording embedded in this assembly.</summary>
    public static ReplayProvider LoadBundled(string name)
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(name)
            ?? throw new InvalidOperationException($"Bundled recording {name} is missing.");
        using var reader = new StreamReader(stream);
        return Parse(reader.ReadToEnd().Split('\n'), name);
    }

    static ReplayProvider Parse(IEnumerable<string> lines, string source)
    {
        var all = lines
            .Where(line => !string.IsNullOrWhiteSpace(line))
            .Select(line => JsonSerializer.Deserialize<Recording>(line, Options) ?? throw new InvalidDataException("Empty recording line."))
            .ToList();
        if (all.Count == 0) throw new InvalidDataException($"{source} has no recordings.");
        return new ReplayProvider(all);
    }

    public static string Serialize(Recording recording) => JsonSerializer.Serialize(recording, Options);

    public Task<DecisionResult> DecideAsync(JsonObject state, IReadOnlyList<ChoiceQuestion> questions, bool reverseOptions, CancellationToken ct)
    {
        var key = ((string?)state["description"] ?? "", (string?)state["unit"] ?? "", reverseOptions);
        if (!recordings.TryGetValue(key, out var recording)) throw new ReplayMissException();
        var result = DecisionWire.ParseResponse(recording.Response, questions, recording.ElapsedMs);
        // The recording has no request body; rebuild the one this build would send to the recorded deployment.
        var rebuilt = DecisionWire.BuildRequest(recording.Deployment, state, questions, reverseOptions).ToJsonString();
        return Task.FromResult(result with { Model = recording.Model, Request = new(rebuilt, Rebuilt: true) });
    }
}
