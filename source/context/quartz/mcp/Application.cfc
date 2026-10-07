/**
 * Entry point of the MCP interface of the Quartz extension: POST /lucee/quartz/mcp/
 * Thin shell, the logic is in org.lucee.extension.quartz.mcp.MCPServer
 */
component {

    this.name = "quartz-mcp";
    this.sessionManagement = false;
    this.clientManagement = false;
    this.setClientCookies = false;
    this.debug = false;

    public boolean function onApplicationStart() {
        application.quartzMcp = new org.lucee.extension.quartz.mcp.MCPServer();
        return true;
    }

    public void function onRequest(required string template) {
        var req = getHttpRequestData(true);
        var body = req.content ?: "";
        if (isBinary(body)) body = toString(body, "utf-8");

        var result = application.quartzMcp.handle({
            "method": req.method,
            "headers": req.headers,
            "remoteAddress": cgi.remote_addr,
            "scheme": cgi.server_port_secure ? "https" : "http",
            "body": body
        });

        header statuscode=result.status;
        loop struct=result.headers index="local.name" item="local.value" {
            header name=name value=value;
        }
        content type="application/json; charset=utf-8" reset=true;
        writeOutput(result.body);
    }
}
