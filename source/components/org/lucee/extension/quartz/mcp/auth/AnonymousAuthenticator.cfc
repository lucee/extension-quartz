/**
 * Lets everybody in (alias "none" / "anonymous"). The only protection left is the "mcp" setting.
 * Only use this behind something that already authenticates (private network, reverse proxy, ...)
 *
 * settings:
 *   permissions  what an anonymous caller may do at most, default "read,write" (still limited by the "mcp" setting)
 */
component implements="Authenticator" {

    public any function init(required struct settings) {
        variables.permissions = arguments.settings.permissions ?: "read,write";
        log log="application" type="warn" text="Quartz MCP: authenticator [anonymous] in use, the MCP interface accepts requests without authentication";
        return this;
    }

    public struct function authenticate(required struct httpRequest) {
        return { "authenticated": true, "principal": "anonymous", "permissions": variables.permissions };
    }
}
