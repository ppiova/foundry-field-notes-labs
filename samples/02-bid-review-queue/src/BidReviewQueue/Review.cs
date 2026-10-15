namespace BidReviewQueue;

public record LineReview(double Confidence, bool AutoAccept, IReadOnlyList<string> Reasons, decimal Amount, decimal PriorityScore);

/// <summary>
/// Turns probabilities into a review decision. A line is accepted automatically only when every answer clears the
/// threshold, no answer abstains, and every selected option is the most probable one. The review queue is ordered by
/// a heuristic priority score: line amount times one minus the weakest selected-answer probability.
/// This is neither expected financial loss nor the probability that the entire line is wrong.
/// </summary>
static class ReviewPolicy
{
    public const double DefaultThreshold = 0.90, MinThreshold = 0.50, MaxThreshold = 0.99;

    public static LineReview Evaluate(BidItem item, DecisionResult result, IReadOnlyList<ChoiceQuestion> questions, double threshold, bool hasReviewerEdits = false)
    {
        var reasons = new List<string>();
        if (hasReviewerEdits) reasons.Add("Reviewer edits require explicit approval; original model probabilities do not score those edits.");
        foreach (var question in questions)
        {
            var answer = result.Answers[question.Name];
            if (answer.Choice == PayItemQuestions.Unclear) reasons.Add($"{question.Label}: the answer is unclear");
            else if (answer.Margin < 0) reasons.Add($"{question.Label}: the selected option is not the most probable");
            else if (answer.Top < threshold) reasons.Add(FormattableString.Invariant($"{question.Label}: {answer.Top:0.00} is below {threshold:0.00}"));
        }
        var confidence = questions.Min(q => result.Answers[q.Name].Top);
        var atRisk = decimal.Round(item.Amount * (decimal)(1 - confidence), 2);
        return new(confidence, reasons.Count == 0, reasons, item.Amount, atRisk);
    }
}

/// <summary>Scoring helpers for the evaluation command.</summary>
static class Scoring
{
    public record Bin(double Low, double High, int Count, double MeanProbability, double Accuracy);

    /// <summary>Multi-class Brier score: the sum of squared differences between probabilities and the one-hot label.</summary>
    public static double Brier(ChoiceAnswer answer, string expected) =>
        answer.Probabilities.Sum(p => Math.Pow(p.Value - (p.Key == expected ? 1 : 0), 2));

    public static IReadOnlyList<Bin> Reliability(IEnumerable<(double Top, bool Correct)> points, IReadOnlyList<double> edges)
    {
        var all = points.ToList();
        var bins = new List<Bin>();
        for (var i = 0; i < edges.Count - 1; i++)
        {
            var (low, high) = (edges[i], edges[i + 1]);
            var last = i == edges.Count - 2;
            var inBin = all.Where(p => p.Top >= low && (last ? p.Top <= high : p.Top < high)).ToList();
            bins.Add(new(low, high, inBin.Count,
                inBin.Count == 0 ? 0 : inBin.Average(p => p.Top),
                inBin.Count == 0 ? 0 : inBin.Count(p => p.Correct) / (double)inBin.Count));
        }
        return bins;
    }

    public static double Percentile(IReadOnlyList<long> values, double percentile)
    {
        if (values.Count == 0) return 0;
        var sorted = values.Order().ToArray();
        var rank = percentile / 100 * (sorted.Length - 1);
        var (lower, upper) = ((int)Math.Floor(rank), (int)Math.Ceiling(rank));
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (rank - lower);
    }
}
