using System.Text.Json;
int passed = 0;
if (RuntimeSettings.Credential("managed-identity") is not Azure.Identity.ManagedIdentityCredential || RuntimeSettings.Credential("azure-cli") is not Azure.Identity.AzureCliCredential) throw new Exception("Explicit credential selection failed.");
Console.WriteLine("PASS Explicit Azure and local credential selection");
passed++;
try { RuntimeSettings.Credential("default"); throw new Exception("Unknown credential mode was accepted."); }
catch (InvalidOperationException) { Console.WriteLine("PASS Unknown credential mode is rejected"); passed++; }
void Reject(Action action, string label) {
    try { action(); } catch (Exception ex) when (ex is InvalidDataException or JsonException) { Console.WriteLine($"PASS {label}"); passed++; return; }
    throw new Exception($"FAIL {label}");
}
const string input = "The portal is unavailable to all users.";
var valid = Triage.Parse("""{"category":"Reliability","priority":"High","summary":"Reported disruption","evidence":"portal is unavailable","nextStep":"Verify scope","draftReply":"Thank you for letting us know"}""");
Triage.Validate(valid, input); passed++;
Reject(() => Triage.Validate(valid with { Evidence = "Invented evidence" }, input), "Reject invented evidence");
Reject(() => Triage.Validate(valid with { Category = "ExecuteTransfer" }, input), "Reject unknown category");
Reject(() => Triage.Validate(valid with { Priority = "Critical" }, input), "Reject unknown priority");
Reject(() => Triage.Validate(valid with { NextStep = "" }, input), "Reject empty field");
Reject(() => Triage.Validate(valid with { Summary = new string('a', 3001) }, input), "Reject oversized output");
Reject(() => Triage.Parse("not JSON"), "Reject malformed provider output");
Reject(() => Triage.Parse("null"), "Reject null output");
var missing = Triage.Parse("{}");
Reject(() => Triage.Validate(missing, input), "Reject missing fields");
Console.WriteLine($"{passed} provider-contract checks passed; no model called.");
