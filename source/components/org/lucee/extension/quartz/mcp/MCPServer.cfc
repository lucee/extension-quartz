/**
 * MCP (Model Context Protocol) server for the Quartz scheduler, JSON-RPC 2.0 over HTTP POST.
 *
 * The server is independent from the web server: handle() takes the request as struct and returns
 * the response as struct, the entry point (context/quartz/mcp) does the translation from and to HTTP.
 *
 * Scheduler config:
 *   "mcp": "read,write"                 what the interface may do, not set = interface disabled, every request is rejected
 *   "mcpAuthenticator": {               who may use it, default is "bearer"
 *       "component": "bearer",          alias (bearer, none) or full path of a component implementing auth.Authenticator
 *       "settings": { ... }             handed to the authenticator
 *   }
 */
component {

    static {
        static.SERVER_NAME = "lucee-quartz";
        static.PROTOCOL_VERSIONS = ["2025-06-18", "2025-03-26", "2024-11-05"];
        static.AUTH_PACKAGE = "org.lucee.extension.quartz.mcp.auth.";
        static.AUTHENTICATOR_ALIASES = {
            "bearer": "BearerAuthenticator",
            "none": "AnonymousAuthenticator",
            "anonymous": "AnonymousAuthenticator"
        };
        // failed authentications per client address and window before the client gets blocked
        static.MAX_FAILURES = 10;
        static.FAILURE_WINDOW_MS = 60000;
    }

    /**
     * @quartzProvider function returning the running Quartz instance, default is the scheduler of the event gateway
     */
    public any function init(any quartzProvider) {
        variables.quartzProvider = arguments.quartzProvider ?: function() {
            return org.lucee.extension.quartz.Quartz::getInstance();
        };
        variables.tools = new ToolRegistry();
        new QuartzTools(variables.quartzProvider).register(variables.tools);
        variables.authenticator = nullValue();
        variables.authenticatorKey = "";
        variables.failures = [:];
        return this;
    }

    // ---------------------------------------------------------------- static helpers

    /** "bearer" -> "org.lucee.extension.quartz.mcp.auth.BearerAuthenticator", anything else is taken as component path */
    public static string function resolveAuthenticatorComponent(required string name) {
        var key = lcase(trim(arguments.name));
        if (structKeyExists(static.AUTHENTICATOR_ALIASES, key)) return static.AUTH_PACKAGE & static.AUTHENTICATOR_ALIASES[key];
        return trim(arguments.name);
    }

    /** list or array of "read" and "write" -> normalized list, anything else is dropped */
    public static string function parsePermissions(any value) {
        if (isNull(arguments.value) || !(isSimpleValue(arguments.value) || isArray(arguments.value))) return "";
        var raw = isArray(arguments.value) ? arrayToList(arguments.value) : arguments.value;
        var result = [];
        loop list=raw delimiters=", ;" item="local.token" {
            token = lcase(trim(token));
            if ((token == "read" || token == "write") && !arrayFind(result, token)) arrayAppend(result, token);
        }
        return arrayToList(result);
    }

    /** permissions both lists have in common */
    public static string function intersect(required string left, required string right) {
        var result = [];
        loop list=arguments.left item="local.p" {
            if (listFindNoCase(arguments.right, p)) arrayAppend(result, p);
        }
        return arrayToList(result);
    }

    // ---------------------------------------------------------------- request handling

    /**
     * @httpRequest struct with method, headers, remoteAddress, scheme, body
     * @return struct with status (number), headers (struct) and body (string)
     */
    public struct function handle(required struct httpRequest) {
        var q = nullValue();
        try {
            q = variables.quartzProvider();
        }
        catch (any e) {
            return reject(503, "Quartz scheduler is not available");
        }
        var config = q.getConfig();

        // no "mcp" setting, no interface
        var allowed = parsePermissions(config.mcp ?: "");
        if (!len(allowed)) return reject(403, "MCP interface is disabled");

        if (uCase(arguments.httpRequest.method ?: "") != "POST") {
            return reject(405, "use POST", { "Allow": "POST" });
        }

        var address = arguments.httpRequest.remoteAddress ?: "";
        if (isBlocked(address)) {
            return reject(429, "too many failed authentication attempts", { "Retry-After": int(static.FAILURE_WINDOW_MS / 1000) });
        }

        // authenticate
        var auth = authenticate(config, arguments.httpRequest);
        if (!auth.authenticated) {
            registerFailure(address);
            var headers = {};
            if (len(auth.challenge ?: "")) headers["WWW-Authenticate"] = auth.challenge;
            return reject(401, "authentication required", headers);
        }
        clearFailures(address);
        var permissions = intersect(auth.permissions, allowed);
        if (!len(permissions)) return reject(403, "no permission");

        return handleRpc(arguments.httpRequest.body ?: "", permissions, auth.principal);
    }

    private struct function authenticate(required struct config, required struct httpRequest) {
        var denied = { "authenticated": false, "principal": "", "permissions": "" };
        try {
            var instance = getAuthenticator(arguments.config);
            var result = instance.authenticate(arguments.httpRequest);
            if (!isStruct(result) || !(result.authenticated ?: false) || !isBoolean(result.authenticated)) {
                if (isStruct(result) && len(result.reason ?: "")) {
                    log log="application" type="info" text="Quartz MCP: request from [#arguments.httpRequest.remoteAddress ?: ''#] rejected: #result.reason#";
                }
                if (isStruct(result) && len(result.challenge ?: "")) denied["challenge"] = result.challenge;
                return denied;
            }
            result["permissions"] = parsePermissions(result.permissions ?: "");
            result["principal"] = result.principal ?: "unknown";
            return result;
        }
        catch (any e) {
            // a broken authenticator must never let anybody in
            log log="application" type="error" exception=e;
            return denied;
        }
    }

    /** the authenticator is created once and again when its configuration changes */
    private any function getAuthenticator(required struct config) {
        var cfg = arguments.config.mcpAuthenticator ?: {};
        if (isSimpleValue(cfg)) cfg = { "component": cfg };
        if (!isStruct(cfg)) throw "invalid [mcpAuthenticator], must be a struct";
        var component = resolveAuthenticatorComponent(cfg.component ?: "bearer");
        var settings = cfg.settings ?: {};
        var key = hash(component & serializeJSON(settings), "quick");

        if (isNull(variables.authenticator) || variables.authenticatorKey != key) {
            lock name="quartz-mcp-authenticator" timeout=10 {
                var instance = createObject("component", component);
                if (!isInstanceOf(instance, static.AUTH_PACKAGE & "Authenticator")) {
                    throw "[#component#] does not implement #static.AUTH_PACKAGE#Authenticator";
                }
                instance = instance.init(settings);
                variables.authenticator = instance;
                variables.authenticatorKey = key;
            }
        }
        return variables.authenticator;
    }

    // ---------------------------------------------------------------- brute force protection

    private boolean function isBlocked(required string address) {
        var list = variables.failures[arguments.address] ?: [];
        var limit = getTickCount() - static.FAILURE_WINDOW_MS;
        var count = 0;
        loop array=list item="local.t" {
            if (t > limit) count++;
        }
        return count >= static.MAX_FAILURES;
    }

    private void function registerFailure(required string address) {
        lock name="quartz-mcp-failures" timeout=5 {
            // do not grow without limit when someone sprays requests from many addresses
            if (structCount(variables.failures) > 1000) variables.failures = [:];
            var limit = getTickCount() - static.FAILURE_WINDOW_MS;
            var current = [];
            loop array=variables.failures[arguments.address] ?: [] item="local.t" {
                if (t > limit) arrayAppend(current, t);
            }
            arrayAppend(current, getTickCount());
            variables.failures[arguments.address] = current;
        }
    }

    private void function clearFailures(required string address) {
        if (structKeyExists(variables.failures, arguments.address)) {
            lock name="quartz-mcp-failures" timeout=5 {
                structDelete(variables.failures, arguments.address);
            }
        }
    }

    // ---------------------------------------------------------------- JSON-RPC

    private struct function handleRpc(required string body, required string permissions, required string principal) {
        if (!isJSON(arguments.body)) return rpcError("", -32700, "Parse error", 400);
        var data = deserializeJSON(arguments.body);
        if (isArray(data)) return rpcError("", -32600, "Batch requests are not supported", 400);
        if (!isStruct(data) || !len(data.method ?: "")) return rpcError("", -32600, "Invalid request", 400);

        var hasId = structKeyExists(data, "id");
        var id = hasId ? data.id : "";
        var params = isStruct(data.params ?: "") ? data.params : {};

        // notifications have no id and are not answered
        if (!hasId) return httpResponse(202, "");

        switch (data.method) {
            case "initialize":
                return rpcResult(id, initialize(params));
            case "ping":
                return rpcResult(id, {});
            case "tools/list":
                return rpcResult(id, { "tools": variables.tools.list(arguments.permissions) });
            case "tools/call":
                return callTool(id, params, arguments.permissions, arguments.principal);
        }
        return rpcError(id, -32601, "Method not found: " & data.method);
    }

    private struct function initialize(required struct params) {
        var requested = arguments.params.protocolVersion ?: "";
        return {
            "protocolVersion": arrayFind(static.PROTOCOL_VERSIONS, requested) ? requested : static.PROTOCOL_VERSIONS[1],
            "capabilities": { "tools": { "listChanged": false } },
            "serverInfo": { "name": static.SERVER_NAME, "version": "1.0.0" }
        };
    }

    private struct function callTool(required any id, required struct params, required string permissions, required string principal) {
        var name = arguments.params.name ?: "";
        if (!len(name)) return rpcError(arguments.id, -32602, "Missing tool name");
        var toolArgs = isStruct(arguments.params.arguments ?: "") ? arguments.params.arguments : {};

        try {
            var result = variables.tools.call(name, toolArgs, arguments.permissions);
            // changes are logged with the caller
            if (variables.tools.getAccess(name) == "write") {
                log log="application" type="info" text="Quartz MCP: [#arguments.principal#] called [#name#]";
            }
            return rpcResult(arguments.id, {
                "content": [ { "type": "text", "text": serializeJSON(var: result, compact: false) } ],
                "isError": false
            });
        }
        catch (tool_not_found e) {
            return rpcError(arguments.id, -32602, e.message);
        }
        catch (permission_denied e) {
            return rpcError(arguments.id, -32001, e.message);
        }
        catch (any e) {
            // a failing tool is reported to the model as result, so it can react to it
            return rpcResult(arguments.id, {
                "content": [ { "type": "text", "text": e.message } ],
                "isError": true
            });
        }
    }

    private struct function rpcResult(required any id, required any result) {
        return httpResponse(200, serializeJSON({ "jsonrpc": "2.0", "id": arguments.id, "result": arguments.result }));
    }

    private struct function rpcError(required any id, required numeric code, required string message, numeric status = 200) {
        var json = serializeJSON({
            "jsonrpc": "2.0",
            "id": arguments.id,
            "error": { "code": arguments.code, "message": arguments.message }
        });
        // errors for requests we could not read have no id, JSON-RPC wants null then
        if (!len(arguments.id & "")) json = replace(json, '"id":""', '"id":null');
        return httpResponse(arguments.status, json);
    }

    private struct function httpResponse(required numeric status, required string body, struct headers = {}) {
        return { "status": arguments.status, "headers": arguments.headers, "body": arguments.body };
    }

    /** rejection before there is a JSON-RPC request to answer */
    private struct function reject(required numeric status, required string message, struct headers = {}) {
        return httpResponse(arguments.status, serializeJSON({ "error": arguments.message }), arguments.headers);
    }
}
