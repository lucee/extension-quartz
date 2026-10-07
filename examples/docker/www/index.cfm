<cfscript>
	/**
	 * Try page for the MCP interface of the Quartz extension.
	 *
	 * The page is an MCP client: it posts JSON-RPC to the endpoint on the server side, with the bearer secret
	 * from the environment, so the secret never reaches the browser. Everything shown here is what an MCP
	 * client (Claude, Cursor, ...) would see.
	 */
	secret = server.system.environment.QUARTZ_MCP_SECRET ?: "";
	endpoint = "http://127.0.0.1:" & getPageContext().getRequest().getLocalPort() & "/lucee/quartz/mcp/";

	/** posts a JSON-RPC request, returns status and body */
	function post( required string body, string token = secret ) {
		http url=endpoint method="post" result="local.res" throwOnError=false timeout=20 {
			httpparam type="header" name="Content-Type" value="application/json";
			if ( len( token ) ) httpparam type="header" name="Authorization" value="Bearer #token#";
			httpparam type="body" value=body;
		}
		return { "status": res.statusCode, "body": res.fileContent };
	}

	function rpc( required string method, struct params = {} ) {
		var res = post( serializeJSON( { "jsonrpc": "2.0", "id": 1, "method": method, "params": params } ) );
		if ( !isJSON( res.body ) ) throw( message = "#res.status#: #res.body#" );
		return deserializeJSON( res.body );
	}

	/** calls a tool, returns the decoded result or throws the error the tool reported */
	function tool( required string name, struct args = {} ) {
		var res = rpc( "tools/call", { "name": name, "arguments": args } );
		if ( structKeyExists( res, "error" ) ) throw( message = res.error.message );
		var text = res.result.content[ 1 ].text;
		if ( res.result.isError ) throw( message = text );
		return deserializeJSON( text );
	}

	message = "";
	raw = "";
	rawResponse = "";
	try {
		switch ( form.action ?: "" ) {
			case "pause": case "unpause": case "execute": case "delete":
				message = tool( "quartz_#form.action#Job", { "name": form.name } ).message;
				break;
			case "pauseAll": case "unpauseAll":
				message = tool( "quartz_#form.action#" ).message;
				break;
			case "append":
				job = { "label": form.label, "component": "org.lucee.extension.quartz.example.SimpleJobExample", "slug": form.slug };
				if ( isNumeric( form.schedule ) ) job[ "interval" ] = form.schedule;
				else job[ "cron" ] = form.schedule;
				message = tool( "quartz_appendJob", { "job": job } ).message;
				break;
			case "raw":
				raw = form.raw;
				rawResponse = post( raw, len( form.token ?: "" ) ? form.token : secret );
				break;
		}
	}
	catch ( any e ) {
		message = "Error: " & e.message;
	}

	// state of the page
	try {
		tools = rpc( "tools/list" ).result.tools;
		triggers = tool( "quartz_listTriggers" );
		meta = tool( "quartz_getMetadata" );
		running = tool( "quartz_listRunning" );
		loadError = "";
	}
	catch ( any e ) {
		loadError = e.message;
		tools = [];
		triggers = [];
		meta = {};
		running = [];
	}
	function h( v ) { return htmlEditFormat( v ?: "" ); }
</cfscript>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Quartz MCP example</title>
<style>
	body { font: 15px/1.5 system-ui, sans-serif; margin: 2rem auto; max-width: 70rem; padding: 0 1rem; color: #222; }
	h1 { margin-bottom: 0; } h2 { margin-top: 2rem; border-bottom: 1px solid #ddd; padding-bottom: .2rem; }
	table { border-collapse: collapse; width: 100%; } th, td { text-align: left; padding: .3rem .6rem; border-bottom: 1px solid #eee; vertical-align: top; }
	code, pre, textarea { font: 13px/1.4 ui-monospace, monospace; } pre { background: #f5f5f5; padding: .6rem; overflow: auto; }
	textarea { width: 100%; box-sizing: border-box; } input[type=text] { padding: .25rem; }
	form { display: inline; } button { cursor: pointer; }
	.msg { background: #eef6ff; border: 1px solid #b6d4fe; padding: .5rem .8rem; margin: 1rem 0; } .err { background: #fff0f0; border-color: #f5b5b5; }
	.muted { color: #777; } .PAUSED { color: #a60; } .NORMAL { color: #070; }
</style>
</head>
<body>
<cfoutput>
<h1>Quartz MCP example</h1>
<p class="muted">Endpoint <code>POST /lucee/quartz/mcp/</code>. This page is an MCP client, it calls the endpoint with the secret from <code>QUARTZ_MCP_SECRET</code>.</p>

<cfif len( message )><div class="msg #left( message, 5 ) == 'Error' ? 'err' : ''#">#h( message )#</div></cfif>
<cfif len( loadError )>
	<div class="msg err">The MCP interface does not answer: #h( loadError )#<br>
	Is the scheduler running (<code>docker compose logs</code>) and is <code>mcp</code> set in <code>config.json</code>?</div>
</cfif>

<h2>Scheduler</h2>
<cfif !structIsEmpty( meta )>
	<p>State <b>#h( meta.state )#</b>, Quartz #h( meta.version )#, #h( meta.threadPoolSize )# threads, job store #h( meta.jobStoreType )#,
	#h( meta.numberOfJobsExecuted )# jobs executed, running since #h( meta.runningSince )#.
	Currently running: #arrayLen( running )#.</p>
</cfif>

<h2>Triggers <small class="muted">(quartz_listTriggers)</small></h2>
<table>
	<tr><th>Label</th><th>Schedule</th><th>State</th><th>Previous</th><th>Next</th><th>Actions <small class="muted">(write)</small></th></tr>
	<cfloop array="#triggers#" item="t">
	<tr>
		<td>#h( t.jobLabel )#<br><span class="muted">#h( t.jobName )#</span></td>
		<td>#h( t.scheduleType )#: <code>#h( t.schedule )#</code></td>
		<td class="#h( t.state )#">#h( t.state )#</td>
		<td>#h( t.previousFireTime )#</td>
		<td>#h( t.nextFireTime )#</td>
		<td>
			<cfloop list="execute,#t.state == 'PAUSED' ? 'unpause' : 'pause'#,delete" item="a">
			<form method="post"><input type="hidden" name="action" value="#a#"><input type="hidden" name="name" value="#h( t.jobName )#"><button>#a#</button></form>
			</cfloop>
		</td>
	</tr>
	</cfloop>
	<cfif !arrayLen( triggers )><tr><td colspan="6" class="muted">no jobs</td></tr></cfif>
</table>
<p>
	<form method="post"><input type="hidden" name="action" value="pauseAll"><button>pause all</button></form>
	<form method="post"><input type="hidden" name="action" value="unpauseAll"><button>unpause all</button></form>
</p>

<h2>Add a dummy job <small class="muted">(quartz_appendJob)</small></h2>
<form method="post">
	<input type="hidden" name="action" value="append">
	Label <input type="text" name="label" value="My dummy job" size="20">
	Slug <input type="text" name="slug" value="my-dummy-job" size="14">
	Cron or interval in seconds <input type="text" name="schedule" value="0/5 * * * * ?" size="16">
	<button>add</button>
</form>
<p class="muted">The job executes the example component, it prints a line to the container log (<code>docker compose logs -f</code>).</p>

<h2>Tools <small class="muted">(tools/list)</small></h2>
<table>
	<tr><th>Name</th><th>Access</th><th>Description</th></tr>
	<cfloop array="#tools#" item="tl">
	<tr><td><code>#h( tl.name )#</code></td><td>#tl.annotations.readOnlyHint ? "read" : "write"#</td><td>#h( tl.description )#</td></tr>
	</cfloop>
</table>

<h2>Raw request</h2>
<p>Send any JSON-RPC request. Clear the token to see the interface reject you, or use a wrong one.</p>
<form method="post">
	<input type="hidden" name="action" value="raw">
	<textarea name="raw" rows="6"><cfif len( raw )>#h( raw )#<cfelse>{ "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": { "name": "quartz_listJobs", "arguments": {} } }</cfif></textarea>
	<p>Bearer token <input type="text" name="token" value="" size="30" placeholder="empty = the configured secret"> <button>send</button></p>
</form>
<cfif isStruct( rawResponse )>
	<p>HTTP status <b>#h( rawResponse.status )#</b></p>
	<pre>#h( rawResponse.body )#</pre>
</cfif>

<h2>From the command line</h2>
<pre>curl -s -X POST http://localhost:8857/lucee/quartz/mcp/ \
  -H "Authorization: Bearer #h( secret )#" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"quartz_listJobs","arguments":{}}}'</pre>
</cfoutput>
</body>
</html>
