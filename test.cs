// <TargetFramework>net9.0</TargetFramework>
// <ImplicitUsings>enable</ImplicitUsings>
// <Nullable>enable</Nullable>

using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization.Metadata; 

namespace CreosonClient
{
    public class CreosonTest
    {
        private string creosonUrl = "http://localhost:9056/creoson";
        private int timeout = 60000;
        private string sessionId = "";
        private string workingDir = @"D:\mydoc\Creoson_test";

        private readonly HttpClient _httpClient;

        public CreosonTest()
        {
            _httpClient = new HttpClient
            {
                Timeout = TimeSpan.FromMilliseconds(timeout)
            };
            _httpClient.DefaultRequestHeaders.Accept.Clear();
            _httpClient.DefaultRequestHeaders.Accept.Add(
                new System.Net.Http.Headers.MediaTypeWithQualityHeaderValue("application/json"));
        }


        private object ConvertJsonElement(JsonElement element)
        {
            return element.ValueKind switch
            {
                JsonValueKind.String => element.GetString(),
                JsonValueKind.Number => element.TryGetInt32(out int i) ? i :
                                        element.TryGetInt64(out long l) ? l :
                                        element.GetDouble(),
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                JsonValueKind.Null => null,
                JsonValueKind.Object => JsonElementToDictionary(element),
                JsonValueKind.Array => element.ToString(), // 简化处理；如需数组支持可扩展
                _ => element.ToString()
            };
        }

        private Dictionary<string, object> JsonElementToDictionary(JsonElement root)
        {
            var dict = new Dictionary<string, object>();
            foreach (var prop in root.EnumerateObject())
            {
                dict[prop.Name] = ConvertJsonElement(prop.Value);
            }
            return dict;
        }

        private async Task<Dictionary<string, object>> CreosonPost(
            string command,
            string functionName,
            Dictionary<string, object>? data = null)
        {
            var requestBody = new Dictionary<string, object>
            {
                { "command", command },
                { "function", functionName }
            };

            if (!string.IsNullOrEmpty(sessionId))
                requestBody["sessionId"] = sessionId;

            if (data != null && data.Count > 0)
                requestBody["data"] = data;

            var serializeOptions = new JsonSerializerOptions
            {
                TypeInfoResolver = new DefaultJsonTypeInfoResolver(),
                WriteIndented = false
            };

            string postData = JsonSerializer.Serialize(requestBody, serializeOptions);
            Console.WriteLine($"[DEBUG] {command}.{functionName} -> {postData}");

            var content = new StringContent(postData, Encoding.UTF8, "application/json");
            HttpResponseMessage response = await _httpClient.PostAsync(creosonUrl, content);

            if (!response.IsSuccessStatusCode)
                throw new Exception($"HTTP Error: {(int)response.StatusCode} - {response.ReasonPhrase}");

            string responseContent = await response.Content.ReadAsStringAsync();

            using var doc = JsonDocument.Parse(responseContent);
            var root = doc.RootElement;

            if (root.TryGetProperty("status", out JsonElement statusElem) &&
                statusElem.ValueKind == JsonValueKind.Object)
            {
                if (statusElem.TryGetProperty("error", out JsonElement errorElem) &&
                    errorElem.GetBoolean())
                {
                    string msg = statusElem.TryGetProperty("message", out JsonElement msgElem)
                        ? msgElem.GetString() ?? "Unknown error"
                        : "Unknown error";
                    throw new Exception($"Creoson Error: {msg}");
                }
            }

            if (command == "connection" && functionName == "connect")
            {
                if (root.TryGetProperty("sessionId", out JsonElement sidElem) &&
                    sidElem.ValueKind != JsonValueKind.Null)
                {
                    sessionId = sidElem.GetString() ?? "";
                    Console.WriteLine($"[SESSION] SessionID: {sessionId}");
                }
            }

            return JsonElementToDictionary(root);
        }

        public async Task StartCreo(Dictionary<string, object> config)
        {
            Console.WriteLine("[1/6] Starting Creo...");
            await CreosonPost("connection", "start_creo", config);
            Console.WriteLine("[1/6] Start command sent");
        }

        public async Task Connect()
        {
            Console.WriteLine("[2/6] Connecting to Creoson...");
            await CreosonPost("connection", "connect", new Dictionary<string, object>());
            Console.WriteLine("[2/6] Connected successfully");
        }

        public async Task CreoCd(string dirName)
        {
            Console.WriteLine($"[3/6] Changing directory to: {dirName}");
            string absDir = Path.GetFullPath(dirName);

            if (!Directory.Exists(absDir))
                throw new Exception($"Invalid directory: {absDir}");

            var data = new Dictionary<string, object>
            {
                { "dirname", absDir }
            };

            await CreosonPost("creo", "cd", data);
            workingDir = absDir;
            Console.WriteLine("[3/6] Directory changed successfully");
        }

        public async Task FileOpen(string file, string generic, bool display, bool activate)
        {
            Console.WriteLine($"[4/6] Opening file: {file}");
            string absFile = Path.GetFullPath(Path.Combine(workingDir, file));

            if (!File.Exists(absFile))
                throw new Exception($"File not found: {absFile}");

            var paramsDict = new Dictionary<string, object>
            {
                { "file", absFile },
                { "display", display },
                { "activate", activate }
            };

            if (!string.IsNullOrEmpty(generic))
                paramsDict["generic"] = generic;

            await CreosonPost("file", "open", paramsDict);
            Console.WriteLine("[4/6] File opened successfully");
        }

        public async Task ParameterSet(string name, string value, string type)
        {
            Console.WriteLine($"[5/6] Setting parameter {name} = {value}");
            var paramsDict = new Dictionary<string, object>
            {
                { "name", name },
                { "type", type },
                { "value", value },
                { "no_create", false },
                { "designate", true }
            };

            await CreosonPost("parameter", "set", paramsDict);
            Console.WriteLine("[5/6] Parameter set successfully");
        }

        public async Task FileSave(string file)
        {
            Console.WriteLine($"[6/6] Saving file: {file}");
            var paramsDict = new Dictionary<string, object>
            {
                { "file", file }
            };

            await CreosonPost("file", "save", paramsDict);
            Console.WriteLine("[6/6] File saved successfully");
        }

        public static async Task Main(string[] args)
        {
            var client = new CreosonTest();
            try
            {
                var config = new Dictionary<string, object>
                {
                    { "start_dir", @"D:\mydoc\Creoson_test" },
                    { "start_command", "nitro_proe_remote.bat" },
                    { "retries", 5 },
                    { "use_desktop", false }
                };

                await client.StartCreo(config);
                await client.Connect();
                await client.CreoCd(@"D:\mydoc\Creoson_test");
                await client.FileOpen("fin.prt", "fin", true, true);
                await client.ParameterSet("test", "C#调用CREOSON添加的参数", "STRING");
                await client.FileSave("fin.prt");

                Console.WriteLine("\n[OK] All operations completed successfully!");
            }
            catch (Exception e)
            {
                Console.WriteLine($"\n[ERR] Execution failed: {e.Message}");
                Console.WriteLine(e.StackTrace);
                Environment.Exit(1);
            }
        }
    }
}