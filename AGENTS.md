# Quartz Scheduler Extension for Lucee

Lucee extension (`.lex`) that runs scheduled jobs with [Quartz](http://www.quartz-scheduler.org/). The code is 100% CFML, there is no Java source in this repo, Quartz comes in through `javaSettings` (Maven) in `Quartz.cfc`.

- Extension id: `E99E43A5-C10E-41E9-878BFC82BAAD99CE`
- Runs as event gateway instance `quartz-task` (started automatically), config file by default `{lucee-server}/quartz/config.json` (overridable with the environment variable `QUARTZ_CONFIGFILE`)
- Targets Lucee 7 (6.2 experimental)
- Tickets are tracked in the Lucee Jira project `LDEV`, commit messages start with the ticket (`LDEV-6468 configurable scheduler thread pool ...`)

## Layout

```
source/
  components/org/lucee/extension/quartz/   all CFCs (packaged to components/)
    Quartz.cfc            the scheduler, loads config, creates/updates/deletes jobs, syncs back to the config file
    QuartzSupport.cfc     base of Quartz.cfc: export, queries, metadata, ${ENV} resolution
    QuartzUtil.cfc        helpers for the job classes
    URLJob / ComponentJob (+ Stateful*)   the Quartz job classes
    mcp/                  MCP interface (see below)
  event-gateways/QuartzGateway.cfc   thin wrapper, holds the config documentation (DEFAULT_CONFIG)
  context/                 packaged to context/ as is
    admin/plugin/          Lucee Administrator pages
    quartz/mcp/            HTTP entry point of the MCP interface (/lucee/quartz/mcp/)
  tags/Schedule.cfc        <cfschedule> replacement
tests/                     TestBox specs, label "quartz"
examples/docker/           Docker compose example: Lucee + the built extension + dummy jobs + a page that uses the MCP interface
build.xml / pom.xml        build, copies source/* into the .lex (see "Build")
```

### Things that are easy to get wrong

- `QuartzGateway.cfc` is a thin shell around `Quartz.cfc` on purpose, Lucee does not unload a component of an event gateway when the extension is updated.
- Reach the running scheduler with `Quartz::getInstance()` (static), it asks the gateway for the instance. It throws when the scheduler is not running.
- A job and its trigger are one unit: one job has exactly one trigger. Job group is always `cfm`, the job name is `hash(slug | url | component, "quick")`.
- The config is read with `${ENV_VAR}` placeholders resolved (`variables.config`), `variables.configUntranslated` keeps them. Write back only the untranslated one.
- `sync()` rewrites the config file after every change (add, pause, resume, delete). It must keep all keys it does not manage (thread pool, `misfirePolicy`, `mcp`, ...), it starts from a copy of `configUntranslated`. Do not build the file from scratch.
- Components are packaged by `**/*.cfc`, everything in `context/` by `**/*.*`. A new folder under `components/` or `context/` needs no build change.

## MCP interface (LDEV-6532)

Entry point `POST /lucee/quartz/mcp/` (`source/context/quartz/mcp/Application.cfc`, a thin shell), logic in `components/.../quartz/mcp/`:

| File | Role |
|---|---|
| `MCPServer.cfc` | JSON-RPC 2.0, permissions, authentication, failed-login blocking. `handle(httpRequest)` takes and returns structs, no HTTP involved, that is what the tests call |
| `ToolRegistry.cfc` | tools with access level `read` or `write`, filters on `list()` and checks on `call()` |
| `QuartzTools.cfc` | the tools, thin wrappers over `Quartz.cfc` |
| `auth/Authenticator.cfc` | interface for authenticators |
| `auth/BearerAuthenticator.cfc`, `auth/AnonymousAuthenticator.cfc` | built in, aliases `bearer`, `none`, `anonymous` |

Rules that must keep holding:

- **Off by default.** No `mcp` setting (or one without `read`/`write`) means every request is rejected, also with the anonymous authenticator.
- **Never open by accident.** No secret, an invalid result, an exception or a component that does not implement the interface means rejected. The effective permission is the intersection of the authenticator result and `mcp`.
- `write` is powerful (it can schedule any component or URL). New tools that change something must be registered with access `write`.
- Tool names start with `quartz_`.

Adding a tool: register it in `QuartzTools.register()` with its access level, implement it on top of `Quartz.cfc`, add specs to `tests/QuartzMcpTest.cfc` (the tool lists in the `TOOLS_READ`/`TOOLS_WRITE` variables are checked against the real list), add it to the table in `README.md`.

Adding an authenticator: implement `auth/Authenticator.cfc`, add the alias to `MCPServer.static.AUTHENTICATOR_ALIASES`, specs, `README.md`.

## Build

Needs JDK 11 and Maven.

```sh
mvn -B clean install
```

Produces `target/quartz-extension-<version>.lex` (with the Quartz jars) and `.lite.lex` (without, Lucee loads them from Maven). The version is in `pom.xml`, it is set by the release commits (`Set version to ...`).

## Tests

Specs are TestBox specs (`extends="org.lucee.cfml.test.LuceeTestCase" labels="quartz"`) in `tests/`. CI installs the built `.lex` into Lucee and runs the Lucee test suite with `testLabels=quartz` and `testAdditional=<repo>/tests` (`.github/workflows/main.yml`).

The scheduler specs start a real scheduler (in memory) from a temp config file, the MCP protocol and authentication specs run against a fake that only holds the config (`tests/McpFakeQuartz.cfc`), no HTTP server is needed. Use far-future cron expressions and `pause: true` so jobs never fire during a test, and stop every scheduler in `afterEach`.

### Running them locally without the Lucee checkout

LuCLI (`lucli run file.cfm`) plus a TestBox checkout is enough, no `.lex` needed. `LuceeTestCase` does not exist there, so provide a stand-in and map everything to the source:

1. Stand-in `org/lucee/cfml/test/LuceeTestCase.cfc` outside the repo: `component extends="testbox.system.BaseSpec" {}`
2. A folder with `org/lucee/extension` as symlink to `source/components/org/lucee/extension` and the stand-in next to it under `org/lucee/cfml/test`
3. A runner script outside the repo:

```cfml
<cfscript>
application action="update" mappings={
    "/org": "/path/to/that/folder/org",
    "/quartzmcptest": "/path/to/Quartz/tests",
    "/testbox": "/path/to/testbox"
};
tb = new testbox.system.TestBox(
    bundles = [ "quartzmcptest.QuartzMcpTest" ],
    reporter = new testbox.system.reports.TextReporter()
);
writeOutput(tb.run());
</cfscript>
```

```sh
lucli run runner.cfm 2>&1 | grep -E 'Pass:|Failures:|Errors:|\(X\)|\(!\)'
```

Gotchas:

- Pass the reporter as an object. TestBox' `new "string.path"()` lookup of a reporter by name fails under LuCLI.
- `application action="update" mappings=...` **replaces** the mappings. When a spec adds one, merge into `getApplicationSettings().mappings` (see `beforeAll()` in `QuartzMcpTest.cfc`), otherwise everything resolved afterwards is gone.
- `getCurrentTemplatePath()` does not work in a script run by `lucli run`, use absolute paths in the runner.
- Failing specs print huge stack traces, filter the output (`grep -v '^\s*at '`).
- `QuartzTest` "fires a relative URL job through internalRequest" needs the `testAdditional` directory the Lucee test suite creates, it fails locally for that reason only.
- Starting a real scheduler takes about half a second, a spec file with many of them takes several seconds.

### Checking the HTTP entry point

The quickest check with the real extension is `examples/docker` (`mvn clean install -DskipTests`, then `docker compose up -d --build` there, see its README), it runs the built `.lex` in Lucee and calls the endpoint over HTTP. Without Docker:


The specs do not go through HTTP. To check `Application.cfc` of the MCP entry point, start a throwaway server with `lucli server start` on a folder holding a copy of `source/context/quartz/mcp/` where `onApplicationStart` creates the `MCPServer` with a fake scheduler provider (`new MCPServer(function() { return new McpFakeQuartz({...}); })`), then `curl -X POST .../quartz/mcp/ -H 'Authorization: Bearer ...' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'`. Stop it with `lucli server stop`.

## Style

- CFML script components, 4 spaces, match the file you edit. `static` is used for constants and helpers (`static.X`, `Quartz::getInstance()`).
- Quote struct keys that go into JSON (`{ "jsonrpc": "2.0" }`), unquoted keys are upper-cased by Lucee. Use `[:]` for an ordered struct.
- Dates that leave the extension as JSON are ISO 8601 UTC (`QuartzTools.normalize()`).
- Log with the `log` tag using the scheduler's log (`variables.logName`) inside the scheduler, `application` elsewhere.
- Document new config keys in `QuartzGateway.DEFAULT_CONFIG` and `README.md`.
