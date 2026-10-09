# Quartz Scheduler Extension for Lucee

A powerful scheduling extension for Lucee 7.0 and later, built on the industry-standard [Quartz Scheduler](http://www.quartz-scheduler.org/) library. The extension is written entirely in CFML (100%), showcasing the power and flexibility of the language.

## Overview

The Quartz Scheduler extension brings industry-standard scheduling capabilities to Lucee, leveraging the most widely adopted scheduling system in the Java world. Starting with Lucee 7, it serves as the modern replacement for the legacy Scheduled Task system.

## Key Features

- **Multiple Job Types**: Schedule URL calls, server-local paths, or CFML component executions
- **Clustering Support**: Distribute scheduled tasks across multiple servers using database or Redis persistence
- **Flexible Scheduling**: Simple interval-based scheduling or powerful cron expressions
- **Event Listeners**: Attach listener components to monitor job execution
- **JSON Configuration**: Define tasks using flexible JSON configuration
- **Component Integration**: Execute CFML components as scheduled tasks with dependency injection
- **Lucee Administrator Integration**: Full-featured frontend for managing jobs, listeners, and storage settings

## Requirements

- Lucee 7.0 or later

## Installation

### Using the Lucee Administrator

1. Navigate to Extensions > Available Extensions
2. Find "Quartz Scheduler" in the list
3. Click "Install"

### Manual Installation

1. Download the extension from [download.lucee.org](https://download.lucee.org)
2. Copy the `.lex` file to the Lucee deploy folder: `lucee-server/deploy`
3. Lucee will automatically detect and install the extension within a minute

### Via .CFConfig.json

You can also define the extension in your `.CFConfig.json` so it is installed automatically when Lucee starts.

**From a local `.lex` file:**

```json
"extensions": [
  {
    "id": "E99E43A5-C10E-41E9-878BFC82BAAD99CE",
    "name": "Quartz Scheduler Extension",
    "resource": "${EXTENSION_PATH}/quartz-extension-1.0.0.48.lex"
  }
]
```

**Downloaded automatically from Maven:**

```json
"extensions": [
  {
    "id": "E99E43A5-C10E-41E9-878BFC82BAAD99CE",
    "name": "Quartz Scheduler Extension",
    "version": "1.0.0.48"
  }
]
```

When only `id` and `version` are provided, Lucee will download the extension directly from Maven at startup.

## Configuration

The scheduler is configured via JSON. The extension installs an event gateway (`quartz-task`) that reads the file set in its `configFile` setting, which defaults to:

```
{lucee-config}/quartz/config.json
```

For the server context this is `<lucee-server directory>/context/quartz/config.json`, for example `/opt/lucee/server/lucee-server/context/quartz/config.json` in the official Docker image. The gateway creates the file with a default content when it first starts; to use a different location, change `configFile` in the `custom` settings of the `quartz-task` gateway.

### Basic Example

```json
{
  "jobs": [
    {
      "label": "External API Call",
      "url": "https://api.example.com/daily-report",
      "cron": "0 0 8 * * ?",
      "pause": false
    },
    {
      "label": "Database Maintenance",
      "component": "com.example.tasks.DatabaseMaintenance",
      "cron": "0 0 3 ? * SUN",
      "mode": "singleton"
    }
  ],
  "listeners": [
    {
      "component": "com.example.scheduler.ExecutionListener",
      "stream": "err"
    }
  ]
}
```

### Clustering Example

```json
{
  "primary": "store",
  "store": {
    "type": "datasource",
    "datasource": "quartz",
    "tablePrefix": "QRTZ_",
    "cluster": true,
    "clusterCheckinInterval": "15000",
    "misfireThreshold": "60000"
  }
}
```

The `primary` setting controls which source is authoritative for job definitions:

| Value | Behaviour |
|-------|-----------|
| `"store"` (default when store is defined) | The store is the source of truth. The config file seeds initial jobs only when the store is empty. |
| `"file"` (default when no store is defined) | The config file is always authoritative. Jobs missing from the file are removed from the store on startup. |

## MCP Interface

The extension includes an [MCP](https://modelcontextprotocol.io) (Model Context Protocol) server, so AI agents and other MCP clients can inspect and manage the scheduler. It is **disabled by default**, as long as `mcp` is not set in the config every request is rejected.

```json
{
  "mcp": "read,write",
  "mcpAuthenticator": {
    "component": "bearer",
    "settings": { "secret": "${QUARTZ_MCP_SECRET}" }
  }
}
```

The endpoint is `POST /lucee/quartz/mcp/` (JSON-RPC 2.0), no additional configuration is needed. Example client config:

```json
{ "mcpServers": { "quartz": { "url": "https://your-host/lucee/quartz/mcp/", "headers": { "Authorization": "Bearer <secret>" } } } }
```

### Permissions (`mcp`)

| Value | Allows |
|---|---|
| not set / empty | nothing, every request is rejected |
| `read` | the tools that only read |
| `write` | the tools that change the scheduler |
| `read,write` | both |

Only the tools covered by the permission are listed, and only those can be called. `write` includes the ability to schedule any component or URL, grant it only to callers you trust with that.

### Tools

| Tool | Permission | Description |
|---|---|---|
| `quartz_listJobs` | read | all jobs |
| `quartz_listTriggers` | read | triggers with schedule, state, previous/next fire time; filter `name`, `group`, `state` |
| `quartz_getJob` | read | complete definition and trigger of a job (`name` or `slug`) |
| `quartz_getMetadata` | read | scheduler state, version, thread pool, job store |
| `quartz_listRunning` | read | jobs currently executing on this node |
| `quartz_appendJob` | write | add or update a job (same format as an entry of `jobs`) |
| `quartz_deleteJob` | write | delete a job |
| `quartz_pauseJob` / `quartz_unpauseJob` | write | pause or unpause a job |
| `quartz_pauseAll` / `quartz_unpauseAll` | write | pause or unpause all jobs |
| `quartz_executeJob` | write | run a job right now |

### Authentication (`mcpAuthenticator`)

Authentication is pluggable. `component` is an alias or the full path of a component implementing `org.lucee.extension.quartz.mcp.auth.Authenticator`, `settings` is handed to it. When `mcpAuthenticator` is not set, `bearer` is used.

| Alias | Component | Description |
|---|---|---|
| `bearer` | `BearerAuthenticator` | `Authorization: Bearer <secret>`. `settings.secret` gives full access, `settings.readSecret` read only access. Without `settings.secret` the environment variable `QUARTZ_MCP_SECRET` (then `MCP_SECRET_KEY`) is used. **Without a secret every request is rejected.** |
| `none`, `anonymous` | `AnonymousAuthenticator` | lets everybody in, `settings.permissions` can limit what they may do. Only use this behind something that authenticates already. |

The effective permission is what the authenticator grants **and** `mcp` allows, an authenticator can never grant more than `mcp`. A client with 10 failed authentications within a minute is blocked for the rest of the minute.

To authenticate in another way (AWS IAM, JWT, ...), write a component implementing the interface:

```cfml
component implements="org.lucee.extension.quartz.mcp.auth.Authenticator" {

    public any function init(required struct settings) {
        variables.settings = arguments.settings;
        return this;
    }

    // httpRequest: method, headers, remoteAddress, scheme, body
    public struct function authenticate(required struct httpRequest) {
        // ... validate the request ...
        return { "authenticated": true, "principal": "someone", "permissions": "read" };
    }
}
```

and reference it in the config: `"mcpAuthenticator": { "component": "com.example.AwsAuthenticator", "settings": { ... } }`. An authenticator that throws, or returns anything invalid, rejects the request.

Use HTTPS, the secret is sent with every request.

A runnable example with Docker (Lucee, the extension, a dummy job and a page that uses the MCP interface) is in [examples/docker](examples/docker).

### Redis store: recovery after a restart

With the Redis store, jobs of a node that was stopped or died while running are taken over by the other nodes. These optional keys in `store` control how fast (milliseconds, requires redis-job-store 2.0 or newer, the defaults apply if not set):

| Key | Default | Meaning |
|-----|---------|---------|
| `clusterCheckinInterval` | `240000` | a node not seen for this long is considered dead. Must be at least 3 x `heartbeatInterval` |
| `releaseTriggersInterval` | `600000` | how often the nodes look for jobs to take over |
| `heartbeatInterval` | `5000` | how often a node tells the cluster it is alive, `0` turns it off |
| `testOnBorrow` | `false` | check Redis connections before use |

Lower `clusterCheckinInterval` (for example `30000`) and `releaseTriggersInterval` (`15000`) only when all nodes of the cluster run the new job store, otherwise a live node running an older version may be taken for dead and its jobs started twice.

## Documentation

Full documentation is available in the [Lucee docs](https://github.com/lucee/lucee-docs):

- [Quartz Scheduler](https://github.com/lucee/lucee-docs/blob/master/docs/recipes/scheduler-quartz.md) — overview, configuration reference, job types, and component jobs
- [Clustering with Quartz Scheduler](https://github.com/lucee/lucee-docs/blob/master/docs/recipes/scheduler-quartz-clustering.md) — database and Redis setup, primary/replica configuration, troubleshooting
- [Component-Based Jobs](https://github.com/lucee/lucee-docs/blob/master/docs/recipes/scheduler-quartz-component-jobs.md) — creating and configuring CFC-based jobs and listeners

## Feedback and Contribution

Issues and suggestions are welcome on the [issue tracker](../../issues).