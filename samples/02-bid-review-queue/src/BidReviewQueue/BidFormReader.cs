using System.Text.Json;
using System.Text.Json.Nodes;

namespace BidReviewQueue;

/// <summary>Validates an uploaded form before replacing the current session's data.</summary>
static class BidFormReader
{
    static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public static BidForm Parse(string text, string fileName)
    {
        var root = JsonNode.Parse(text);
        var items = root switch
        {
            JsonArray array => array,
            JsonObject obj when obj["items"] is JsonArray array => array,
            _ => throw new InvalidDataException("The file needs an items array of pay items."),
        };
        if (items.Count is 0 or > 150) throw new InvalidDataException("The file needs 1 to 150 pay items.");
        var parsed = items.Select((node, index) =>
        {
            if (node is not JsonObject) throw new InvalidDataException($"Pay item {index + 1} must be an object.");
            var item = node.Deserialize<BidItem>(Json) ?? throw new InvalidDataException($"Pay item {index + 1} is empty.");
            return item.Validate() is { } problem ? throw new InvalidDataException($"Pay item {index + 1}: {problem}") : item;
        }).ToList();
        if (parsed.Select(i => i.Number).Distinct().Count() != parsed.Count) throw new InvalidDataException("Pay item numbers must be unique.");
        var title = (root as JsonObject)?["title"] is JsonValue value && value.TryGetValue<string>(out var t) && !string.IsNullOrWhiteSpace(t)
            ? t : Path.GetFileNameWithoutExtension(fileName);
        return new BidForm(title, "Loaded from your file. Use synthetic data. Only the lines you decide are sent to the selected engine.", parsed);
    }
}
