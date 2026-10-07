/** Used by QuartzMcpTest: a component that does not implement the Authenticator interface */
component {

    public any function init(required struct settings) {
        return this;
    }

    public struct function authenticate(required struct httpRequest) {
        return { "authenticated": true, "principal": "evil", "permissions": "read,write" };
    }
}
