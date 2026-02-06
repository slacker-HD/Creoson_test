import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;

public class test {
    private String creosonUrl = "http://localhost:9056/creoson";
    private int timeout = 60000;
    private String sessionId = "";
    private String workingDir = "D:\\mydoc\\Creoson_test";

    private static class SimpleJson {
        public static String toJson(Map<String, Object> map) {
            StringBuilder sb = new StringBuilder("{");
            for (Map.Entry<String, Object> entry : map.entrySet()) {
                if (sb.length() > 1) sb.append(",");
                sb.append("\"").append(escapeJson(entry.getKey())).append("\":");
                sb.append(serializeValue(entry.getValue()));
            }
            sb.append("}");
            return sb.toString();
        }

        private static String serializeValue(Object val) {
            if (val == null) return "null";
            if (val instanceof String) return "\"" + escapeJson((String) val) + "\"";
            if (val instanceof Boolean || val instanceof Number) return val.toString();
            if (val instanceof Map) return toJson((Map<String, Object>) val);
            return "\"" + escapeJson(val.toString()) + "\"";
        }

        private static String escapeJson(String s) {
            return s.replace("\\", "\\\\")
                   .replace("\"", "\\\"")
                   .replace("\n", "\\n")
                   .replace("\r", "\\r")
                   .replace("\t", "\\t");
        }

        public static Map<String, Object> fromJson(String json) {
            Map<String, Object> result = new HashMap<>();
            json = json.trim();
            if (json.startsWith("{")) json = json.substring(1);
            if (json.endsWith("}")) json = json.substring(0, json.length() - 1);
            
            String[] pairs = json.split(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");
            for (String pair : pairs) {
                String[] kv = pair.split(":", 2);
                if (kv.length == 2) {
                    String key = kv[0].trim().replace("\"", "");
                    String value = kv[1].trim();
                    result.put(key, parseValue(value));
                }
            }
            return result;
        }

        private static Object parseValue(String value) {
            if (value.equals("true")) return Boolean.TRUE;
            if (value.equals("false")) return Boolean.FALSE;
            if (value.equals("null")) return null;
            if (value.startsWith("\"") && value.endsWith("\"")) {
                return value.substring(1, value.length() - 1);
            }
            try {
                if (value.contains(".")) return Double.parseDouble(value);
                return Integer.parseInt(value);
            } catch (NumberFormatException e) {
                return value;
            }
        }
    }

    private Map<String, Object> creosonPost(String command, String functionName, Map<String, Object> data) throws Exception {
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("command", command);
        requestBody.put("function", functionName);
        if (!sessionId.isEmpty()) requestBody.put("sessionId", sessionId);
        if (data != null && !data.isEmpty()) requestBody.put("data", data);

        String postData = SimpleJson.toJson(requestBody);
        System.out.printf("[DEBUG] %s.%s -> %s%n", command, functionName, postData);

        URL url = new URL(creosonUrl);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        try {
            conn.setRequestMethod("POST");
            conn.setDoOutput(true);
            conn.setConnectTimeout(timeout);
            conn.setReadTimeout(timeout);
            conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8");

            try (OutputStream os = conn.getOutputStream()) {
                os.write(postData.getBytes(StandardCharsets.UTF_8));
            }

            int responseCode = conn.getResponseCode();
            if (responseCode != 200) {
                throw new IOException("HTTP Error: " + responseCode);
            }

            StringBuilder response = new StringBuilder();
            try (BufferedReader br = new BufferedReader(
                    new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = br.readLine()) != null) response.append(line);
            }

            Map<String, Object> result = SimpleJson.fromJson(response.toString());
            
            Object statusObj = result.get("status");
            if (statusObj instanceof Map) {
                Map<?, ?> status = (Map<?, ?>) statusObj;
                Object errorObj = status.get("error");
                if (Boolean.TRUE.equals(errorObj)) {
                    String msg = status.get("message") != null ? status.get("message").toString() : "Unknown error";
                    throw new Exception("Creoson Error: " + msg);
                }
            }

            if ("connection".equals(command) && "connect".equals(functionName)) {
                Object sid = result.get("sessionId");
                if (sid != null) {
                    sessionId = sid.toString();
                    System.out.println("[SESSION] SessionID: " + sessionId);
                }
            }

            return result;
        } finally {
            conn.disconnect();
        }
    }

    public void startCreo(Map<String, Object> config) throws Exception {
        System.out.println("[1/6] Starting Creo...");
        creosonPost("connection", "start_creo", config);
        System.out.println("[1/6] Start command sent");
    }

    public void connect() throws Exception {
        System.out.println("[2/6] Connecting to Creoson...");
        creosonPost("connection", "connect", new HashMap<>());
        System.out.println("[2/6] Connected successfully");
    }

    public void creoCd(String dirName) throws Exception {
        System.out.printf("[3/6] Changing directory to: %s%n", dirName);
        Path absDir = Paths.get(dirName).toAbsolutePath().normalize();
        if (!Files.exists(absDir) || !Files.isDirectory(absDir)) {
            throw new Exception("Invalid directory: " + absDir);
        }
        Map<String, Object> data = new HashMap<>();
        data.put("dirname", absDir.toString());
        creosonPost("creo", "cd", data);
        this.workingDir = absDir.toString();
        System.out.println("[3/6] Directory changed successfully");
    }

    public void fileOpen(String file, String generic, boolean display, boolean activate) throws Exception {
        System.out.printf("[4/6] Opening file: %s%n", file);
        Path absFile = Paths.get(workingDir, file).toAbsolutePath().normalize();
        if (!Files.exists(absFile)) {
            throw new Exception("File not found: " + absFile);
        }
        
        Map<String, Object> params = new HashMap<>();
        params.put("file", absFile.toString());
        params.put("display", display);
        params.put("activate", activate);
        if (generic != null && !generic.isEmpty()) {
            params.put("generic", generic);
        }
        creosonPost("file", "open", params);
        System.out.println("[4/6] File opened successfully");
    }

    public void parameterSet(String name, String value, String type) throws Exception {
        System.out.printf("[5/6] Setting parameter %s = %s%n", name, value);
        Map<String, Object> params = new HashMap<>();
        params.put("name", name);
        params.put("type", type);
        params.put("value", value);
        params.put("no_create", false);
        params.put("designate", true);
        creosonPost("parameter", "set", params);
        System.out.println("[5/6] Parameter set successfully");
    }

    public void fileSave(String file) throws Exception {
        System.out.printf("[6/6] Saving file: %s%n", file);
        Map<String, Object> params = new HashMap<>();
        params.put("file", file);
        creosonPost("file", "save", params);
        System.out.println("[6/6] File saved successfully");
    }

    public static void main(String[] args) {
        test client = new test(); 
        try {
            Map<String, Object> config = new HashMap<>();
            config.put("start_dir", "D:\\mydoc\\Creoson_test");
            config.put("start_command", "nitro_proe_remote.bat");
            config.put("retries", 5);
            config.put("use_desktop", false);

            client.startCreo(config);
            client.connect();
            client.creoCd("D:\\mydoc\\Creoson_test");
            client.fileOpen("fin.prt", "fin", true, true);
            client.parameterSet("test", "Java调用CREOSON添加的参数", "STRING");
            client.fileSave("fin.prt");

            System.out.println("\n[OK] All operations completed successfully!");
        } catch (Exception e) {
            System.err.println("\n[ERR] Execution failed: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
}