/**
 * Holds the MCP tools. Every tool has an access level ("read" or "write"), a caller
 * only sees and can only call the tools its permissions cover.
 */
component {

    public any function init() {
        variables.tools = [:];
        return this;
    }

    public ToolRegistry function register(
        required string name,
        required string access,
        required string description,
        required any handler,
        struct inputSchema = {}
    ) {
        if (!listFindNoCase("read,write", arguments.access)) throw "invalid access [#arguments.access#] for tool [#arguments.name#], use read or write";
        variables.tools[arguments.name] = {
            "name": arguments.name,
            "access": lcase(arguments.access),
            "description": arguments.description,
            "handler": arguments.handler,
            "inputSchema": normalizeSchema(arguments.inputSchema)
        };
        return this;
    }

    public boolean function has(required string name) {
        return structKeyExists(variables.tools, arguments.name);
    }

    public string function getAccess(required string name) {
        return variables.tools[arguments.name].access;
    }

    /** descriptors (as sent with tools/list) of all tools the permissions cover */
    public array function list(required string permissions) {
        var result = [];
        loop struct=variables.tools index="local.name" item="local.tool" {
            if (!listFindNoCase(arguments.permissions, tool.access)) continue;
            arrayAppend(result, {
                "name": tool.name,
                "description": tool.description,
                "inputSchema": tool.inputSchema,
                "annotations": { "readOnlyHint": tool.access == "read" }
            });
        }
        return result;
    }

    /**
     * @throws tool_not_found, permission_denied
     */
    public any function call(required string name, required struct toolArguments, required string permissions) {
        if (!has(arguments.name)) {
            throw(type: "tool_not_found", message: "Unknown tool [#arguments.name#]");
        }
        var tool = variables.tools[arguments.name];
        if (!listFindNoCase(arguments.permissions, tool.access)) {
            throw(type: "permission_denied", message: "Tool [#arguments.name#] requires [#tool.access#] permission");
        }
        return tool.handler(arguments.toolArguments);
    }

    private struct function normalizeSchema(required struct schema) {
        if (!structKeyExists(arguments.schema, "type")) arguments.schema["type"] = "object";
        if (!structKeyExists(arguments.schema, "properties")) arguments.schema["properties"] = {};
        if (!structKeyExists(arguments.schema, "required")) arguments.schema["required"] = [];
        return arguments.schema;
    }
}
