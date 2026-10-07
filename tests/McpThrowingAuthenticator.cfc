/** Authenticator used by QuartzMcpTest: always fails with an exception */
component implements="org.lucee.extension.quartz.mcp.auth.Authenticator" {

    public any function init(required struct settings) {
        return this;
    }

    public struct function authenticate(required struct httpRequest) {
        throw "this authenticator is broken";
    }
}
