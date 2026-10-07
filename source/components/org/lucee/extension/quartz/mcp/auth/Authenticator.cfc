/**
 * Contract for the authentication of MCP requests.
 *
 * The component to use is selected in the scheduler config:
 *
 *   "mcpAuthenticator": { "component": "bearer", "settings": { ... } }
 *
 * "component" is either an alias ("bearer", "none") or the full path of a component
 * implementing this interface, e.g. to authenticate against an AWS service.
 *
 * An implementation must never throw to signal a failed login, it returns
 * authenticated=false instead. Everything that throws, or returns an invalid
 * result, is treated as a rejected request.
 */
interface {

    /**
     * @settings the "settings" struct from the "mcpAuthenticator" config (environment variables already resolved)
     */
    public any function init(required struct settings);

    /**
     * @httpRequest struct with the keys
     *   method        HTTP method
     *   headers       struct with all request headers
     *   remoteAddress address of the client
     *   scheme        "http" or "https"
     *   body          raw request body as string (needed for signature validation)
     *
     * @return struct with the keys
     *   authenticated boolean, required
     *   principal     string, who is calling (used for logging)
     *   permissions   "read", "write" or "read,write"; what this caller is allowed to do at most. The effective
     *                 permission is the intersection with the "mcp" setting.
     *   challenge     string, optional value for the WWW-Authenticate response header when rejecting
     *   reason        string, optional, why the request was rejected (logged, never sent to the client)
     */
    public struct function authenticate(required struct httpRequest);
}
