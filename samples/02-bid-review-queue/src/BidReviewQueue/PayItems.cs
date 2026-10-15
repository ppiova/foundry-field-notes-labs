using System.Reflection;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace BidReviewQueue;

public record BidItem(string Number, string Description, string Unit, decimal Quantity, decimal UnitPrice)
{
    public decimal Amount => decimal.Round(Quantity * UnitPrice, 2);

    /// <summary>The state sent to the model. Quantities and prices stay in the application.</summary>
    public JsonObject ToState() => new() { ["pay_item"] = Number, ["description"] = Description, ["unit"] = Unit };

    public string? Validate()
    {
        if (string.IsNullOrWhiteSpace(Number) || Number.Length > 20) return "Each pay item needs a number of 1 to 20 characters.";
        if (string.IsNullOrWhiteSpace(Description) || Description.Trim().Length < 3 || Description.Length > PayItemQuestions.MaxDescription)
            return $"Each description needs 3 to {PayItemQuestions.MaxDescription} characters.";
        if (string.IsNullOrWhiteSpace(Unit) || Unit.Length > 10) return "Each pay item needs a unit of 1 to 10 characters.";
        if (Quantity is < 0 or > 100_000_000 || UnitPrice is < 0 or > 100_000_000) return "Quantity and unit price must be between 0 and 100,000,000.";
        return null;
    }
}

record BidForm(string Title, string Note, IReadOnlyList<BidItem> Items);

record LabeledPayItem(string Number, string Description, string Unit, IReadOnlyDictionary<string, string> Expected)
{
    public BidItem ToItem() => new(Number, Description, Unit, 1, 0);
}

record LabeledSet(string Note, IReadOnlyList<LabeledPayItem> Items);

static class DataSets
{
    static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    public static BidForm Demo { get; } = Load<BidForm>("sample-bid-form.json");
    public static LabeledSet Labeled { get; } = Load<LabeledSet>("labeled-pay-items.json");

    static T Load<T>(string name)
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(name)
            ?? throw new InvalidOperationException($"Embedded data file {name} is missing.");
        return JsonSerializer.Deserialize<T>(stream, Options) ?? throw new InvalidDataException($"{name} is empty.");
    }
}

/// <summary>
/// The application writes every option. Fixed taxonomies cover the system and the work type; spans found in the
/// description by regular expressions cover sizes, materials and depth bands, so the model can choose a span but
/// cannot invent or retype a number.
/// </summary>
static partial class PayItemQuestions
{
    public const string None = "none";
    public const string Unclear = "unclear";
    public const int MaxDescription = 500;
    const int MaxSpans = 8;

    public static readonly IReadOnlyList<DecisionOption> Systems =
    [
        new("sanitary_gravity", "Gravity sanitary sewer: sewer pipe, manholes, service laterals, cleanouts"),
        new("force_main", "Sanitary force main, lift station, or pump station"),
        new("water", "Potable water: water mains, valves, hydrants, services, meters"),
        new("storm", "Storm drainage: storm pipe, inlets, culverts, end sections"),
        new("general", "Not tied to one utility system: mobilization, traffic control, bonds, survey, restoration, allowances"),
        new(Unclear, "The description does not identify the system"),
    ];

    public static readonly IReadOnlyList<DecisionOption> WorkTypes =
    [
        new("furnish_install", "Furnish and install new work, including items priced per unit installed"),
        new("furnish_only", "Furnish or deliver material only; installation is paid elsewhere"),
        new("install_only", "Install owner-furnished material only"),
        new("remove_abandon", "Remove, demolish, cut and plug, grout-fill, or abandon existing work"),
        new("connect_adjust", "Connect to, adjust, relocate, repair, or rehabilitate existing work"),
        new("support_work", "Temporary or support work: bypass pumping, dewatering, sheeting and shoring, testing, inspection, temporary services"),
        new("restoration", "Restore pavement, curbs, sidewalks, driveways, sod, markings, or landscaping"),
        new("general_conditions", "Project-wide items: mobilization, demobilization, bonds, traffic control, survey, documentation, allowances"),
        new(Unclear, "The description does not say what work is paid"),
    ];

    public static IReadOnlyList<ChoiceQuestion> For(string description)
    {
        var questions = new List<ChoiceQuestion>
        {
            new("system", "System", "Which utility system does this bid pay item belong to?", Systems),
            new("work_type", "Work type", "What work does this bid pay item pay for?", WorkTypes),
        };
        AddSpanQuestion(questions, "diameter", "Size", "nominal size of the pipe, valve, or fitting that this pay item pays for", Diameter(), description);
        AddSpanQuestion(questions, "material", "Material", "material of the pipe or structure that this pay item pays for", Material(), description);
        AddSpanQuestion(questions, "depth_band", "Depth band", "depth range in which this pay item is paid", DepthBand(), description);
        return questions;
    }

    public static IReadOnlyList<string> Candidates(Regex pattern, string text) =>
        pattern.Matches(text)
            .Select(m => Whitespace().Replace(m.Value.Trim(), " "))
            .Distinct(StringComparer.Ordinal)
            .Take(MaxSpans)
            .ToList();

    static void AddSpanQuestion(List<ChoiceQuestion> questions, string name, string label, string what, Regex pattern, string text)
    {
        var spans = Candidates(pattern, text);
        if (spans.Count == 0) return;
        var options = spans.Select(s => new DecisionOption(s, $"The text '{s}' in the description"))
            .Append(new DecisionOption(None, "None of these spans"))
            .ToList();
        questions.Add(new(name, label, $"Which of these spans is the {what}? Choose none if none of them is.", options));
    }

    // Inches: 8", 8-inch, 8 inches, 8-in. Fractions such as 3/4" are skipped rather than split.
    [GeneratedRegex("""(?<![\d./])\d{1,2}(?:\.\d{1,2})?(?:\s?["”″]|\s?-?\s?inch(?:es)?\b|-in\b\.?)""", RegexOptions.IgnoreCase)]
    internal static partial Regex Diameter();

    [GeneratedRegex("""\bPVC\b(?:\s?\(?C-?9(?:00|09)\)?)?(?:,?\s?S?DR[\s-]?\d{1,2})?|\bC-?9(?:00|09)\b|\bductile iron\b|\bD\.I\.P\.|\bDIP\b|\bHDPE\b(?:\s?DR[\s-]?\d{1,2})?|\bRCP\b|\breinforced concrete\b|\bVCP\b|\bvitrified clay\b|\bCMP\b|\bcorrugated metal\b|\bcopper\b|\bsteel\b|\bfiberglass\b|\bcast iron\b""", RegexOptions.IgnoreCase)]
    internal static partial Regex Material();

    // Feet ranges such as 0'-6', 10' to 12', 12 to 14 ft, and open bands such as Over 12'.
    [GeneratedRegex("""(?<![\d.])\d{1,2}(?:\.\d)?\s?(?:'|ft\b\.?|feet)?\s?(?:-|–|to)\s?\d{1,2}(?:\.\d)?\s?(?:'|ft\b\.?|feet)|(?:greater than|deeper than|more than|over|less than|under|>|<)\s?\d{1,2}(?:\.\d)?\s?(?:'|ft\b\.?|feet)""", RegexOptions.IgnoreCase)]
    internal static partial Regex DepthBand();

    [GeneratedRegex(@"\s+")]
    private static partial Regex Whitespace();
}
