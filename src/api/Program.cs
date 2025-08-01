using RemoteMcpMsGraph.Configuration;
using RemoteMcpMsGraph.Tools;

var builder = WebApplication.CreateBuilder(args);

// Configure Azure AD options
builder.Services.Configure<AzureAdOptions>(
    builder.Configuration.GetSection("AzureAd"));

// Register services
builder.Services.AddHttpContextAccessor();
builder.Services.AddControllers();

// Configure MCP server
builder.Services.AddMcpServer()
    .WithHttpTransport(options =>
    {
        options.Stateless = true;
    })
    .WithTools<ShowUserProfileTool>();

var app = builder.Build();

app.MapControllers();
app.MapMcp();

app.Run();
