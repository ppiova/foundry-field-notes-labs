using Azure.Core;
using Azure.Identity;

static class RuntimeSettings
{
    public static TokenCredential Credential(string? mode) => mode switch
    {
        null or "" or "azure-cli" => new AzureCliCredential(),
        "managed-identity" => new ManagedIdentityCredential(ManagedIdentityId.SystemAssigned),
        _ => throw new InvalidOperationException("FOUNDRY_CREDENTIAL must be azure-cli or managed-identity.")
    };
}
