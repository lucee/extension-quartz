/**
 * Tests for the MCP interface (LDEV-6532).
 *
 * The protocol, permission and authentication tests run against a fake that only provides the
 * scheduler config, the tool tests run against a real scheduler. No HTTP server is needed, the
 * server is called with a request struct like the entry point does.
 */
component extends="org.lucee.cfml.test.LuceeTestCase" labels="quartz" {

    variables.COMP = "org.lucee.extension.quartz.example.SimpleJobExample";
    variables.SECRET = "s3cret-for-tests";
    variables.TOOLS_READ = [ "quartz_getJob", "quartz_getMetadata", "quartz_listJobs", "quartz_listRunning", "quartz_listTriggers" ];
    variables.TOOLS_WRITE = [ "quartz_appendJob", "quartz_deleteJob", "quartz_executeJob", "quartz_pauseAll", "quartz_pauseJob", "quartz_unpauseAll", "quartz_unpauseJob" ];

    function beforeAll() {
        // the test authenticators live next to this test
        // add to the existing mappings, an update replaces them
        var mappings = getApplicationSettings().mappings;
        mappings[ "/quartzmcptest" ] = getDirectoryFromPath( getCurrentTemplatePath() );
        application action="update" mappings=mappings;
    }

    function run() {

        describe( "MCP static helpers", function() {

            it( "maps authenticator aliases to their component", function() {
                var pkg = "org.lucee.extension.quartz.mcp.auth.";
                expect( server().resolveAuthenticatorComponent( "bearer" ) ).toBe( pkg & "BearerAuthenticator" );
                expect( server().resolveAuthenticatorComponent( "Bearer" ) ).toBe( pkg & "BearerAuthenticator" );
                expect( server().resolveAuthenticatorComponent( " none " ) ).toBe( pkg & "AnonymousAuthenticator" );
                expect( server().resolveAuthenticatorComponent( "anonymous" ) ).toBe( pkg & "AnonymousAuthenticator" );
            } );

            it( "takes everything else as component path", function() {
                expect( server().resolveAuthenticatorComponent( "com.example.AwsAuthenticator" ) ).toBe( "com.example.AwsAuthenticator" );
            } );

            it( "parses the permissions", function() {
                expect( server().parsePermissions( "read,write" ) ).toBe( "read,write" );
                expect( server().parsePermissions( " Write , READ " ) ).toBe( "write,read" );
                expect( server().parsePermissions( "read write" ) ).toBe( "read,write" );
                expect( server().parsePermissions( [ "read" ] ) ).toBe( "read" );
                expect( server().parsePermissions( "read,read" ) ).toBe( "read" );
                expect( server().parsePermissions( "admin,root" ) ).toBe( "" );
                expect( server().parsePermissions( "" ) ).toBe( "" );
                expect( server().parsePermissions( true ) ).toBe( "" );
                expect( server().parsePermissions( { "a": 1 } ) ).toBe( "" );
            } );

            it( "intersects permissions", function() {
                expect( server().intersect( "read,write", "read" ) ).toBe( "read" );
                expect( server().intersect( "write", "read" ) ).toBe( "" );
                expect( server().intersect( "read,write", "write,read" ) ).toBe( "read,write" );
            } );
        } );

        describe( "MCP interface disabled by default", function() {

            it( "rejects everything without the [mcp] setting", function() {
                var s = newServer( {} );
                var res = s.handle( rpc( "ping", {}, bearer() ) );
                expect( res.status ).toBe( 403 );
            } );

            it( "rejects everything with an empty or invalid [mcp] setting", function() {
                loop array=[ "", "none", "admin", true ] item="local.value" {
                    var s = newServer( { "mcp": value, "mcpAuthenticator": { "component": "none" } } );
                    expect( s.handle( rpc( "ping" ) ).status ).toBe( 403 );
                }
            } );

            it( "rejects when the scheduler is not available", function() {
                var s = new org.lucee.extension.quartz.mcp.MCPServer( function() { throw "not running"; } );
                expect( s.handle( rpc( "ping" ) ).status ).toBe( 503 );
            } );

            it( "only accepts POST", function() {
                var s = newServer( { "mcp": "read", "mcpAuthenticator": { "component": "none" } } );
                var req = rpc( "ping" );
                req.method = "GET";
                var res = s.handle( req );
                expect( res.status ).toBe( 405 );
                expect( res.headers.Allow ).toBe( "POST" );
            } );
        } );

        describe( "BearerAuthenticator", function() {

            it( "is the default authenticator", function() {
                // no [mcpAuthenticator] in the config -> bearer, without secret in the environment nothing gets in
                var s = newServer( { "mcp": "read,write" } );
                var res = s.handle( rpc( "ping", {}, bearer() ) );
                expect( res.status ).toBe( 401 );
            } );

            it( "rejects a request without token", function() {
                var s = bearerServer();
                var res = s.handle( rpc( "ping" ) );
                expect( res.status ).toBe( 401 );
                expect( res.headers[ "WWW-Authenticate" ] ).toBe( "Bearer" );
            } );

            it( "rejects a wrong token and other schemes", function() {
                var s = bearerServer();
                expect( s.handle( rpc( "ping", {}, bearer( "wrong" ) ) ).status ).toBe( 401 );
                expect( s.handle( rpc( "ping", {}, bearer( variables.SECRET & "x" ) ) ).status ).toBe( 401 );
                expect( s.handle( rpc( "ping", {}, { "authorization": "Basic " & variables.SECRET } ) ).status ).toBe( 401 );
                expect( s.handle( rpc( "ping", {}, { "authorization": "Bearer" } ) ).status ).toBe( 401 );
            } );

            it( "accepts the secret", function() {
                var res = bearerServer().handle( rpc( "ping", {}, bearer() ) );
                expect( res.status ).toBe( 200 );
                expect( res.headers ).toBeStruct();
            } );

            it( "rejects every request when no secret is configured", function() {
                var s = newServer( { "mcp": "read,write", "mcpAuthenticator": { "component": "bearer", "settings": {} } } );
                // also not with an empty token or the empty secret
                expect( s.handle( rpc( "ping", {}, bearer( "" ) ) ).status ).toBe( 401 );
                expect( s.handle( rpc( "ping", {}, bearer( "x" ) ) ).status ).toBe( 401 );
            } );

            it( "never accepts the insecure default secret of the lucee mcp extension", function() {
                var s = newServer( { "mcp": "read,write", "mcpAuthenticator": { "component": "bearer", "settings": { "secret": "change-me-in-production" } } } );
                expect( s.handle( rpc( "ping", {}, bearer( "change-me-in-production" ) ) ).status ).toBe( 401 );
            } );

            it( "gives the [readSecret] read access only", function() {
                var s = newServer( { "mcp": "read,write", "mcpAuthenticator": { "component": "bearer", "settings": { "secret": variables.SECRET, "readSecret": "read-only-secret" } } } );
                var names = toolNames( s, bearer( "read-only-secret" ) );
                expect( names ).toBe( variables.TOOLS_READ );
                expect( toolNames( s, bearer() ) ).toBe( arraySort2( variables.TOOLS_READ, variables.TOOLS_WRITE ) );
            } );
        } );

        describe( "anonymous authenticator", function() {

            it( "lets everybody in by alias [none]", function() {
                var s = newServer( { "mcp": "read", "mcpAuthenticator": { "component": "none" } } );
                expect( s.handle( rpc( "ping" ) ).status ).toBe( 200 );
            } );

            it( "lets everybody in by alias [anonymous] and by string config", function() {
                expect( newServer( { "mcp": "read", "mcpAuthenticator": { "component": "Anonymous" } } ).handle( rpc( "ping" ) ).status ).toBe( 200 );
                expect( newServer( { "mcp": "read", "mcpAuthenticator": "none" } ).handle( rpc( "ping" ) ).status ).toBe( 200 );
            } );

            it( "still obeys the [mcp] setting", function() {
                var s = newServer( { "mcp": "read", "mcpAuthenticator": { "component": "none" } } );
                expect( toolNames( s ) ).toBe( variables.TOOLS_READ );
            } );

            it( "can be limited with the [permissions] setting", function() {
                var s = newServer( { "mcp": "read,write", "mcpAuthenticator": { "component": "none", "settings": { "permissions": "read" } } } );
                expect( toolNames( s ) ).toBe( variables.TOOLS_READ );
            } );
        } );

        describe( "custom authenticator", function() {

            it( "is loaded by component path", function() {
                var s = newServer( customConfig( "read,write" ) );
                expect( s.handle( rpc( "ping" ) ).status ).toBe( 401 );
                expect( s.handle( rpc( "ping", {}, { "X-Test-Token": "abc" } ) ).status ).toBe( 200 );
            } );

            it( "can not grant more than the [mcp] setting allows", function() {
                var cfg = customConfig( "read,write" );
                cfg.mcp = "read";
                var s = newServer( cfg );
                expect( toolNames( s, { "X-Test-Token": "abc" } ) ).toBe( variables.TOOLS_READ );
            } );

            it( "can grant less than the [mcp] setting allows", function() {
                var s = newServer( customConfig( "read" ) );
                expect( toolNames( s, { "X-Test-Token": "abc" } ) ).toBe( variables.TOOLS_READ );
            } );

            it( "rejects when the authenticator grants nothing usable", function() {
                var s = newServer( customConfig( "admin" ) );
                expect( s.handle( rpc( "ping", {}, { "X-Test-Token": "abc" } ) ).status ).toBe( 403 );
            } );

            it( "rejects when the authenticator throws", function() {
                var s = newServer( { "mcp": "read,write", "mcpAuthenticator": { "component": "quartzmcptest.McpThrowingAuthenticator" } } );
                expect( s.handle( rpc( "ping", {}, bearer() ) ).status ).toBe( 401 );
            } );

            it( "rejects when the component does not exist", function() {
                var s = newServer( { "mcp": "read,write", "mcpAuthenticator": { "component": "quartzmcptest.DoesNotExist" } } );
                expect( s.handle( rpc( "ping", {}, bearer() ) ).status ).toBe( 401 );
            } );

            it( "rejects when the component does not implement the Authenticator interface", function() {
                var s = newServer( { "mcp": "read,write", "mcpAuthenticator": { "component": "quartzmcptest.McpNotAnAuthenticator" } } );
                expect( s.handle( rpc( "ping", {}, bearer() ) ).status ).toBe( 401 );
            } );

            it( "follows a changed authenticator config", function() {
                var cfg = { "mcp": "read", "mcpAuthenticator": { "component": "bearer", "settings": { "secret": variables.SECRET } } };
                var quartz = new quartzmcptest.McpFakeQuartz( cfg );
                var s = new org.lucee.extension.quartz.mcp.MCPServer( function() { return quartz; } );
                expect( s.handle( rpc( "ping", {}, bearer() ) ).status ).toBe( 200 );

                quartz.getConfig().mcpAuthenticator = { "component": "bearer", "settings": { "secret": "another" } };
                expect( s.handle( rpc( "ping", {}, bearer() ) ).status ).toBe( 401 );
                expect( s.handle( rpc( "ping", {}, bearer( "another" ) ) ).status ).toBe( 200 );
            } );
        } );

        describe( "failed authentication", function() {

            it( "blocks a client after too many failures", function() {
                var s = bearerServer();
                loop times=10 {
                    expect( s.handle( rpc( "ping", {}, bearer( "wrong" ) ) ).status ).toBe( 401 );
                }
                // even the right token is not accepted now
                var res = s.handle( rpc( "ping", {}, bearer() ) );
                expect( res.status ).toBe( 429 );
                expect( res.headers ).toHaveKey( "Retry-After" );
            } );

            it( "does not block other clients", function() {
                var s = bearerServer();
                loop times=10 {
                    s.handle( rpc( "ping", {}, bearer( "wrong" ) ) );
                }
                var req = rpc( "ping", {}, bearer() );
                req.remoteAddress = "10.9.9.9";
                expect( s.handle( req ).status ).toBe( 200 );
            } );
        } );

        describe( "JSON-RPC protocol", function() {

            it( "answers initialize with the requested protocol version", function() {
                var res = call( anonymousServer(), "initialize", { "protocolVersion": "2025-03-26" } );
                expect( res.result.protocolVersion ).toBe( "2025-03-26" );
                expect( res.result.capabilities ).toHaveKey( "tools" );
                expect( res.result.serverInfo.name ).toBe( "lucee-quartz" );
            } );

            it( "falls back to the latest protocol version it knows", function() {
                var res = call( anonymousServer(), "initialize", { "protocolVersion": "1999-01-01" } );
                expect( res.result.protocolVersion ).toBe( "2025-06-18" );
            } );

            it( "answers ping", function() {
                var res = call( anonymousServer(), "ping" );
                expect( res.jsonrpc ).toBe( "2.0" );
                expect( res.id ).toBe( 1 );
                expect( res.result ).toBeStruct();
            } );

            it( "does not answer notifications", function() {
                var req = rpc( "notifications/initialized" );
                req.body = serializeJSON( { "jsonrpc": "2.0", "method": "notifications/initialized" } );
                var res = anonymousServer().handle( req );
                expect( res.status ).toBe( 202 );
                expect( res.body ).toBe( "" );
            } );

            it( "reports unknown methods", function() {
                var res = call( anonymousServer(), "resources/list" );
                expect( res.error.code ).toBe( -32601 );
            } );

            it( "reports invalid JSON", function() {
                var req = rpc( "ping" );
                req.body = "{ not json";
                var res = anonymousServer().handle( req );
                expect( res.status ).toBe( 400 );
                expect( deserializeJSON( res.body ).error.code ).toBe( -32700 );
            } );

            it( "rejects batches and requests without method", function() {
                var req = rpc( "ping" );
                req.body = "[{""jsonrpc"":""2.0"",""id"":1,""method"":""ping""}]";
                expect( deserializeJSON( anonymousServer().handle( req ).body ).error.code ).toBe( -32600 );
                req.body = "{""jsonrpc"":""2.0"",""id"":1}";
                expect( deserializeJSON( anonymousServer().handle( req ).body ).error.code ).toBe( -32600 );
            } );

            it( "describes every tool with an input schema", function() {
                var tools = call( anonymousServer( "read,write" ), "tools/list" ).result.tools;
                expect( tools.len() ).toBe( variables.TOOLS_READ.len() + variables.TOOLS_WRITE.len() );
                loop array=tools item="local.tool" {
                    expect( tool.inputSchema.type ).toBe( "object" );
                    expect( len( tool.description ) ).toBeGT( 0 );
                    expect( tool.annotations.readOnlyHint ).toBe( arrayFind( variables.TOOLS_READ, tool.name ) > 0 );
                }
            } );

            it( "lists only the tools the permission covers", function() {
                expect( toolNames( anonymousServer( "read" ) ) ).toBe( variables.TOOLS_READ );
                expect( toolNames( anonymousServer( "write" ) ) ).toBe( variables.TOOLS_WRITE );
            } );

            it( "refuses to call a tool the permission does not cover", function() {
                var res = call( anonymousServer( "read" ), "tools/call", { "name": "quartz_pauseAll", "arguments": {} } );
                expect( res.error.code ).toBe( -32001 );
                expect( res ).notToHaveKey( "result" );
            } );

            it( "refuses to call an unknown tool", function() {
                var res = call( anonymousServer( "read" ), "tools/call", { "name": "quartz_nothing", "arguments": {} } );
                expect( res.error.code ).toBe( -32602 );
            } );
        } );

        describe( "MCP tools", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "lists jobs and triggers", function() {
                var s = toolServer( [ compJob(), urlJob() ] );

                var jobs = tool( s, "quartz_listJobs" );
                expect( jobs.len() ).toBe( 2 );

                var triggers = tool( s, "quartz_listTriggers" );
                expect( triggers.len() ).toBe( 2 );
                expect( triggers[ 1 ] ).toHaveKey( "nextFireTime" );

                // filters
                expect( tool( s, "quartz_listTriggers", { "state": "paused" } ).len() ).toBe( 2 );
                expect( tool( s, "quartz_listTriggers", { "state": "normal" } ).len() ).toBe( 0 );
                expect( tool( s, "quartz_listTriggers", { "name": hash( variables.COMP, "quick" ) } ).len() ).toBe( 1 );
                expect( tool( s, "quartz_listTriggers", { "group": "nothing" } ).len() ).toBe( 0 );
            } );

            it( "gets a job by name or slug", function() {
                var s = toolServer( [ compJob() ] );
                var name = hash( variables.COMP, "quick" );

                var job = tool( s, "quartz_getJob", { "name": name } );
                expect( job.name ).toBe( name );
                expect( job.group ).toBe( "cfm" );
                expect( job.job.component ).toBe( variables.COMP );
                expect( job.trigger.state ).toBe( "PAUSED" );

                tool( s, "quartz_appendJob", { "job": { "slug": "my-slug", "label": "by slug", "url": "/never.cfm", "interval": 3600, "pause": true } } );
                expect( tool( s, "quartz_getJob", { "slug": "my-slug" } ).job.label ).toBe( "by slug" );
            } );

            it( "reports an unknown job as tool error", function() {
                var s = toolServer( [] );
                var res = call( s, "tools/call", { "name": "quartz_getJob", "arguments": { "name": "nope" } } );
                expect( res.result.isError ).toBeTrue();
                expect( res.result.content[ 1 ].text ).toInclude( "not found" );

                var res = call( s, "tools/call", { "name": "quartz_pauseJob", "arguments": {} } );
                expect( res.result.isError ).toBeTrue();
            } );

            it( "returns the scheduler metadata", function() {
                var s = toolServer( [], { "threadPoolCount": 3 } );
                var meta = tool( s, "quartz_getMetadata" );
                expect( meta.state ).toBe( "running" );
                expect( meta.started ).toBeTrue();
                expect( meta.threadPoolSize ).toBe( 3 );
                expect( meta.config.threadPoolCount ).toBe( 3 );
                expect( meta.jobStoreType ).toBe( "Memory" );
            } );

            it( "lists running jobs", function() {
                expect( tool( toolServer( [] ), "quartz_listRunning" ) ).toBe( [] );
            } );

            it( "appends, pauses, unpauses and deletes a job", function() {
                var s = toolServer( [] );
                var added = tool( s, "quartz_appendJob", { "job": { "label": "added", "component": variables.COMP, "cron": "0 0 0 1 1 ? 2099", "pause": true } } );
                expect( added.success ).toBeTrue();
                expect( tool( s, "quartz_listJobs" ).len() ).toBe( 1 );
                expect( tool( s, "quartz_getJob", { "name": added.name } ).trigger.state ).toBe( "PAUSED" );

                tool( s, "quartz_unpauseJob", { "name": added.name } );
                expect( tool( s, "quartz_getJob", { "name": added.name } ).trigger.state ).toBe( "NORMAL" );

                tool( s, "quartz_pauseJob", { "name": added.name } );
                expect( tool( s, "quartz_getJob", { "name": added.name } ).trigger.state ).toBe( "PAUSED" );

                tool( s, "quartz_deleteJob", { "name": added.name } );
                expect( tool( s, "quartz_listJobs" ).len() ).toBe( 0 );
            } );

            it( "updates a job when appended again", function() {
                var s = toolServer( [] );
                tool( s, "quartz_appendJob", { "job": { "label": "one", "component": variables.COMP, "cron": "0 0 0 1 1 ? 2099", "pause": true } } );
                tool( s, "quartz_appendJob", { "job": { "label": "two", "component": variables.COMP, "cron": "0 0 0 1 1 ? 2099", "pause": true } } );
                expect( tool( s, "quartz_listJobs" ).len() ).toBe( 1 );
            } );

            it( "rejects invalid jobs", function() {
                var s = toolServer( [] );
                var bad = [
                    {},
                    { "job": "text" },
                    { "job": { "cron": "0 0 0 1 1 ? 2099" } },
                    { "job": { "component": variables.COMP } }
                ];
                loop array=bad item="local.args" {
                    var res = call( s, "tools/call", { "name": "quartz_appendJob", "arguments": args } );
                    expect( res.result.isError ).toBeTrue();
                }
                expect( tool( s, "quartz_listJobs" ).len() ).toBe( 0 );
            } );

            it( "pauses and unpauses all jobs", function() {
                var s = toolServer( [ compJob(), urlJob() ] );
                tool( s, "quartz_unpauseAll" );
                expect( tool( s, "quartz_listTriggers", { "state": "paused" } ).len() ).toBe( 0 );
                tool( s, "quartz_pauseAll" );
                expect( tool( s, "quartz_listTriggers", { "state": "paused" } ).len() ).toBe( 2 );
            } );

            it( "executes a job immediately", function() {
                var s = toolServer( [ compJob() ] );
                var res = tool( s, "quartz_executeJob", { "name": hash( variables.COMP, "quick" ) } );
                expect( res.success ).toBeTrue();
                expect( res.message ).toBe( "job triggered" );
            } );

            it( "keeps the [mcp] settings when the scheduler writes its config", function() {
                var s = toolServer( [ compJob() ], { "mcp": "read,write", "threadPoolCount": 3 } );
                tool( s, "quartz_unpauseAll" );
                tool( s, "quartz_pauseJob", { "name": hash( variables.COMP, "quick" ) } );
                var saved = deserializeJSON( fileRead( variables.instances[ 1 ].getConfigFile() ) );
                expect( saved.mcp ).toBe( "read,write" );
                expect( saved.threadPoolCount ).toBe( 3 );
            } );
        } );
    }

    // ------------------------------------------------------------------ helpers

    private any function server() {
        return createObject( "component", "org.lucee.extension.quartz.mcp.MCPServer" );
    }

    /** server on top of a fake that only holds the config */
    private any function newServer( required struct config ) {
        var quartz = new quartzmcptest.McpFakeQuartz( arguments.config );
        return new org.lucee.extension.quartz.mcp.MCPServer( function() { return quartz; } );
    }

    private any function bearerServer() {
        return newServer( { "mcp": "read,write", "mcpAuthenticator": { "component": "bearer", "settings": { "secret": variables.SECRET } } } );
    }

    private any function anonymousServer( string mcp = "read" ) {
        return newServer( { "mcp": arguments.mcp, "mcpAuthenticator": { "component": "none" } } );
    }

    private struct function customConfig( required string permissions ) {
        return {
            "mcp": "read,write",
            "mcpAuthenticator": {
                "component": "quartzmcptest.McpTestAuthenticator",
                "settings": { "token": "abc", "permissions": arguments.permissions }
            }
        };
    }

    private struct function bearer( string token = variables.SECRET ) {
        return { "authorization": "Bearer " & arguments.token };
    }

    /** a request as the entry point hands it to the server */
    private struct function rpc( required string method, struct params = {}, struct headers = {} ) {
        return {
            "method": "POST",
            "headers": arguments.headers,
            "remoteAddress": "127.0.0.1",
            "scheme": "https",
            "body": serializeJSON( { "jsonrpc": "2.0", "id": 1, "method": arguments.method, "params": arguments.params } )
        };
    }

    /** calls the server and returns the decoded JSON-RPC response */
    private struct function call( required any server, required string method, struct params = {}, struct headers = {} ) {
        var res = arguments.server.handle( rpc( arguments.method, arguments.params, arguments.headers ) );
        expect( res.status ).toBe( 200 );
        return deserializeJSON( res.body );
    }

    private array function toolNames( required any server, struct headers = {} ) {
        var names = [];
        loop array=call( arguments.server, "tools/list", {}, arguments.headers ).result.tools item="local.tool" {
            arrayAppend( names, tool.name );
        }
        arraySort( names, "text" );
        return names;
    }

    private array function arraySort2( required array left, required array right ) {
        var all = duplicate( arguments.left );
        all.append( arguments.right, true );
        arraySort( all, "text" );
        return all;
    }

    /** server on top of a real scheduler with full access */
    private any function toolServer( required array jobs, struct extra = {} ) {
        var data = { "jobs": arguments.jobs, "mcp": "read,write", "mcpAuthenticator": { "component": "none" } };
        structAppend( data, arguments.extra );
        var path = getTempDirectory() & "quartz-mcp-test-" & createUniqueId() & ".json";
        fileWrite( path, serializeJSON( data ) );
        var q = new org.lucee.extension.quartz.Quartz( path );
        q.start();
        arrayAppend( variables.instances, q );
        return new org.lucee.extension.quartz.mcp.MCPServer( function() { return q; } );
    }

    /** calls a tool and returns its decoded result */
    private any function tool( required any server, required string name, struct args = {} ) {
        var res = call( arguments.server, "tools/call", { "name": arguments.name, "arguments": arguments.args } );
        expect( res ).notToHaveKey( "error" );
        expect( res.result.isError ).toBeFalse( res.result.content[ 1 ].text );
        return deserializeJSON( res.result.content[ 1 ].text );
    }

    private void function stopAll() {
        if ( isNull( variables.instances ) ) return;
        loop array=variables.instances item="local.q" {
            try { q.stop(); } catch ( any e ) {}
        }
        variables.instances = [];
    }

    private struct function compJob() {
        return { "label": "comp", "component": variables.COMP, "cron": "0 0 0 1 1 ? 2099", "pause": true };
    }

    private struct function urlJob() {
        return { "label": "url", "url": "/never.cfm", "interval": 3600, "startAt": "2099-01-01", "pause": true };
    }
}
