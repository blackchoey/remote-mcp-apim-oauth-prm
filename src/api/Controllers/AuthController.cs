using Microsoft.AspNetCore.Mvc;

namespace RemoteMcpMsGraph.Controllers;

[ApiController]
[Route("auth")]
public class AuthController : ControllerBase
{
    private readonly ILogger<AuthController> _logger;

    public AuthController(ILogger<AuthController> logger)
    {
        _logger = logger;
    }

    [HttpGet("callback")]
    public IActionResult Callback([FromQuery] string? code, [FromQuery] string? error, [FromQuery] string? state)
    {
        if (!string.IsNullOrEmpty(error))
        {
            _logger.LogWarning("Authentication callback received error: {Error}", error);
            return Content(GenerateErrorHtml(error), "text/html");
        }

        if (!string.IsNullOrEmpty(code))
        {
            _logger.LogInformation("Authentication callback received authorization code successfully");
            return Content(GenerateSuccessHtml(), "text/html");
        }

        _logger.LogWarning("Authentication callback received without code or error");
        return Content(GenerateErrorHtml("No authorization code or error received"), "text/html");
    }

    private static string GenerateSuccessHtml()
    {
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Authentication Successful</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
                    .container { max-width: 600px; margin: 0 auto; background-color: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                    .success { color: #28a745; }
                    .icon { font-size: 48px; text-align: center; margin-bottom: 20px; }
                    h1 { color: #333; text-align: center; }
                    p { color: #666; line-height: 1.6; }
                    .highlight { background-color: #e7f3ff; padding: 15px; border-left: 4px solid #007bff; margin: 20px 0; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>Authentication Successful!</h1>
                    <p>You have successfully logged in and granted the required permissions.</p>
                    <div class="highlight">
                        <strong>Next Steps:</strong>
                        <ul>
                            <li>You can now close this browser window</li>
                            <li>Return to your AI Agent and try using the MCP server again</li>
                            <li>The server should now be able to access your Microsoft Graph data</li>
                        </ul>
                    </div>
                    <p><em>Thank you for completing the authentication process!</em></p>
                </div>
            </body>
            </html>
            """;
    }

    private static string GenerateErrorHtml(string error)
    {
        return $@"
            <!DOCTYPE html>
            <html>
            <head>
                <title>Authentication Error</title>
                <style>
                    body {{ font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }}
                    .container {{ max-width: 600px; margin: 0 auto; background-color: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
                    .error {{ color: #dc3545; }}
                    .icon {{ font-size: 48px; text-align: center; margin-bottom: 20px; }}
                    h1 {{ color: #333; text-align: center; }}
                    p {{ color: #666; line-height: 1.6; }}
                    .highlight {{ background-color: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0; }}
                </style>
            </head>
            <body>
                <div class=""container"">
                    <h1>Authentication Error</h1>
                    <p>There was an error during the authentication process:</p>
                    <div class=""highlight"">
                        <strong>Error:</strong> {error}
                    </div>
                    <p>Please try the authentication process again or contact your administrator if the problem persists.</p>
                </div>
            </body>
            </html>";
    }
}
