namespace RemoteMcpMsGraph.Configuration;

public class AzureAdOptions
{
    /// <summary>
    /// The Azure AD tenant ID.
    /// </summary>
    public string TenantId { get; set; } = string.Empty;

    /// <summary>
    /// The client ID of the application.
    /// </summary>
    public string ClientId { get; set; } = string.Empty;

    /// <summary>
    /// The client ID of the managed identity used as federated credential.
    /// </summary>
    public string ManagedIdentityClientId { get; set; } = string.Empty;
}
