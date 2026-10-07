/**
 * Authenticator used by QuartzMcpTest: accepts the header X-Test-Token with the configured token
 * and grants the configured permissions (stand-in for e.g. an AWS specific authenticator)
 */
component implements="org.lucee.extension.quartz.mcp.auth.Authenticator" {

    public any function init(required struct settings) {
        variables.settings = arguments.settings;
        return this;
    }

    public struct function authenticate(required struct httpRequest) {
        if ((arguments.httpRequest.headers["X-Test-Token"] ?: "") == variables.settings.token) {
            return { "authenticated": true, "principal": "test-user", "permissions": variables.settings.permissions };
        }
        return { "authenticated": false, "reason": "wrong token" };
    }
}
