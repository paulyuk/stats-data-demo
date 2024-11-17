using Google.Protobuf;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.OpenAI.Assistants;
using Microsoft.Extensions.Logging;
using System.Text;
using System.Text.Json;

namespace AssistantSample;

public class BaseballAgentClient
{
    private readonly HttpClient _httpClient;
    private readonly string baseballServiceUrl = Environment.GetEnvironmentVariable("SPORTS_SERVICE_URL") ?? "https://baseball-agent.wittycliff-2af5d188.australiaeast.azurecontainerapps.io/inference";

    public BaseballAgentClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<string> PostQueryAsync(string query)
    {
        var content = new StringContent(JsonSerializer.Serialize(new { query }), Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync(baseballServiceUrl, content);
        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadAsStringAsync();

        return result;
    }
}

/// <summary>
/// Defines assistant skills that can be triggered by the assistant chat bot.
/// </summary>
public class AssistantSkills
{
    readonly ITodoManager todoManager;
    readonly ILogger<AssistantSkills> logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="AssistantSkills"/> class.
    /// </summary>
    /// <remarks>
    /// This constructor is called by the Azure Functions runtime's dependency injection container.
    /// </remarks>
    public AssistantSkills(ITodoManager todoManager, ILogger<AssistantSkills> logger)
    {
        this.todoManager = todoManager ?? throw new ArgumentNullException(nameof(todoManager));
        this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    /// <summary>
    /// Called by the assistant to add ACA agent.
    /// </summary>
    [Function(nameof(GetBaseballStats))]
    public async Task<string> GetBaseballStats(
        [AssistantSkillTrigger("Answer any baseball question, e.g. which players were born in 1800s?", Model = "%CHAT_MODEL_DEPLOYMENT_NAME%")]
            string question
    )
    {
        var httpClient = new HttpClient();
        var client = new BaseballAgentClient(httpClient);

        var response = await client.PostQueryAsync(question);
        this.logger.LogInformation("Baseball stats: {result}", response);
        
        return response;    
    }

    /// <summary>
    /// Called by the assistant to fetch the list of previously created todo tasks.
    /// </summary>
    [Function(nameof(GetTodos))]
    public Task<IReadOnlyList<TodoItem>> GetTodos(
        [AssistantSkillTrigger(
            "Fetch the list of previously created todo tasks",
            Model = "%CHAT_MODEL_DEPLOYMENT_NAME%"
        )]
            object inputIgnored
    )
    {
        this.logger.LogInformation("Fetching list of todos");

        return this.todoManager.GetTodosAsync();
    }
}
