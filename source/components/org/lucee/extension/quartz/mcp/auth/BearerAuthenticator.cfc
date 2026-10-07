/**
 * Authenticates with a static secret sent as "Authorization: Bearer <secret>".
 *
 * settings:
 *   secret      full access (read and write, limited by the "mcp" setting)
 *   readSecret  optional, read only access
 *
 * When "secret" is not set, the environment variable QUARTZ_MCP_SECRET (then MCP_SECRET_KEY) is used.
 * Without any secret every request is rejected, this authenticator never lets anybody in by default.
 */
component implements="Authenticator" {

    static {
        // value used by the lucee mcp extension as default, never accepted here
        static.INSECURE_DEFAULT = "change-me-in-production";
    }

    public any function init(required struct settings) {
        variables.secret = trim(arguments.settings.secret ?: "");
        if (!len(variables.secret)) {
            variables.secret = trim(server.system.environment.QUARTZ_MCP_SECRET ?: server.system.environment.MCP_SECRET_KEY ?: "");
        }
        if (variables.secret == static.INSECURE_DEFAULT) variables.secret = "";
        variables.readSecret = trim(arguments.settings.readSecret ?: "");
        if (variables.readSecret == static.INSECURE_DEFAULT) variables.readSecret = "";
        return this;
    }

    public struct function authenticate(required struct httpRequest) {
        if (!len(variables.secret) && !len(variables.readSecret)) {
            return deny("no secret configured");
        }

        var header = trim(arguments.httpRequest.headers.authorization ?: "");
        if (!reFindNoCase("^Bearer\s+\S", header)) return deny("missing bearer token");
        var token = trim(reReplaceNoCase(header, "^Bearer\s+", ""));

        if (len(variables.secret) && isEqual(token, variables.secret)) {
            return { "authenticated": true, "principal": "bearer", "permissions": "read,write" };
        }
        if (len(variables.readSecret) && isEqual(token, variables.readSecret)) {
            return { "authenticated": true, "principal": "bearer-read", "permissions": "read" };
        }
        return deny("invalid token");
    }

    private struct function deny(required string reason) {
        return { "authenticated": false, "principal": "", "permissions": "", "challenge": "Bearer", "reason": arguments.reason };
    }

    /** constant time comparison, so the response time does not reveal how much of a token matched */
    private boolean function isEqual(required string left, required string right) {
        return createObject("java", "java.security.MessageDigest").isEqual(
            charsetDecode(arguments.left, "utf-8"),
            charsetDecode(arguments.right, "utf-8")
        );
    }
}
