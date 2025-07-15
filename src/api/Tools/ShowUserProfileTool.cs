using Microsoft.Extensions.Options;
using ModelContextProtocol.Server;
using RemoteMcpMsGraph.Configuration;
using RemoteMcpMsGraph.Utilities;
using System.ComponentModel;
using System.Text.Json;
using Azure.Identity;
using Microsoft.Graph;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Identity.Client;

namespace RemoteMcpMsGraph.Tools;

/// <summary>
/// MCP tool for retrieving the current user's profile information from Microsoft Graph.
/// </summary>
[McpServerToolType]
public class ShowUserProfileTool
{
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly AzureAdOptions _azureAdOptions;
    private readonly ILogger<ShowUserProfileTool> _logger;

    public ShowUserProfileTool(
        IHttpContextAccessor httpContextAccessor,
        IOptions<AzureAdOptions> azureAdOptions,
        ILogger<ShowUserProfileTool> logger)
    {
        _httpContextAccessor = httpContextAccessor;
        _azureAdOptions = azureAdOptions.Value;
        _logger = logger;
    }

    /// <summary>
    /// Retrieves and displays the current user's profile information from Microsoft Graph.
    /// </summary>
    /// <returns>A JSON representation of the user's profile information.</returns>
    [McpServerTool, Description("Retrieves the current user's profile information from Microsoft Graph API.")]
    public async Task<string> ShowUserProfile()
    {
        var httpContext = _httpContextAccessor.HttpContext;
        if (httpContext == null)
        {
            _logger.LogError("HTTP context is not available");
            return CreateErrorResponse("HTTP context is not available");
        }
        if (!httpContext.Request.Headers.TryGetValue("Authorization", out var authHeader) ||
            string.IsNullOrWhiteSpace(authHeader.ToString()))
        {
            _logger.LogWarning("Authorization header not found in request");
            return CreateErrorResponse("Authorization header not found in request");
        }

        string authHeaderValue = authHeader.ToString();

        // Extract Bearer token
        if (!authHeaderValue.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("Authorization header does not contain a Bearer token");
            return CreateErrorResponse("Authorization header must contain a Bearer token");
        }

        string accessToken = authHeaderValue.Substring("Bearer ".Length).Trim();
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            _logger.LogWarning("Bearer token is empty in Authorization header");
            return CreateErrorResponse("Bearer token is empty in Authorization header");
        }
        _logger.LogDebug("Access token found in Authorization header");

        try
        {
            var cancellationToken = httpContext.RequestAborted;
            var graphClient = GraphClientHelper.CreateGraphClient(accessToken, _azureAdOptions);
            var user = await graphClient.Me.GetAsync(cancellationToken: cancellationToken);

            if (user == null)
            {
                _logger.LogWarning("User profile not found in Microsoft Graph API response");
                return CreateErrorResponse("User profile not found");
            }

            var userProfile = new
                {
                    DisplayName = user.DisplayName,
                    Email = user.Mail ?? user.UserPrincipalName,
                    Id = user.Id,
                    JobTitle = user.JobTitle,
                    Department = user.Department,
                    OfficeLocation = user.OfficeLocation
                };

            return JsonSerializer.Serialize(userProfile, CreateJsonSerializerOptions());
        }
        catch (AuthenticationFailedException ex)
        {
            if (ex.InnerException is MsalClaimsChallengeException msalException && 
                msalException.ErrorCode == "invalid_grant")
            {
                var loginUrl = GenerateLoginUrl();
                var consentResponse = new 
                { 
                    error = "User consent required",
                    message = "Please provide the following URL to user and ask them to login in order to call Microsoft Graph API",
                    loginUrl = loginUrl
                };
                return JsonSerializer.Serialize(consentResponse, CreateJsonSerializerOptions());
            }

            _logger.LogError(ex, "Authentication failed while retrieving user profile");
            return CreateErrorResponse($"Authentication failed: {ex.Message}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error occurred while retrieving user profile");
            return CreateErrorResponse($"An unexpected error occurred: {ex.Message}");
        }
    }

    private string GenerateLoginUrl()
    {
        var httpContext = _httpContextAccessor.HttpContext;
        var host = httpContext!.Request.Host.Value;
        var callbackUrl = $"https://{host}/auth/callback";

        // Generate PKCE parameters
        var codeVerifier = GenerateCodeVerifier();
        var codeChallenge = GenerateCodeChallenge(codeVerifier);

        var scopes = "User.Read"; // Microsoft Graph scope
        var loginUrl = $"https://login.microsoftonline.com/{_azureAdOptions.TenantId}/oauth2/v2.0/authorize?" +
                      $"client_id={_azureAdOptions.ClientId}&" +
                      $"response_type=code&" +
                      $"redirect_uri={Uri.EscapeDataString(callbackUrl)}&" +
                      $"response_mode=query&" +
                      $"scope={Uri.EscapeDataString(scopes)}&" +
                      $"state=consent_required&" +
                      $"code_challenge={Uri.EscapeDataString(codeChallenge)}&" +
                      $"code_challenge_method=S256";

        return loginUrl;
    }

    private static string GenerateCodeVerifier()
    {
        const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
        var random = new Random();
        var codeVerifier = new StringBuilder();
        
        // Code verifier should be 43-128 characters long
        for (int i = 0; i < 128; i++)
        {
            codeVerifier.Append(chars[random.Next(chars.Length)]);
        }
        
        return codeVerifier.ToString();
    }

    private static string GenerateCodeChallenge(string codeVerifier)
    {
        using var sha256 = SHA256.Create();
        var challengeBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(codeVerifier));
        return Convert.ToBase64String(challengeBytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static JsonSerializerOptions CreateJsonSerializerOptions()
    {
        return new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };
    }

    private static string CreateErrorResponse(string message)
    {
        var errorResponse = new { error = message };
        return JsonSerializer.Serialize(errorResponse, CreateJsonSerializerOptions());
    }
}
