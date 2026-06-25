# Quartz Scheduler Extension for Lucee

A powerful scheduling extension for Lucee 6.2 and 7, built on the industry-standard [Quartz Scheduler](http://www.quartz-scheduler.org/) library. The extension is written entirely in CFML (100%), showcasing the power and flexibility of the language.

## Version History & Breaking Changes

### v1.1.0+ (Current)

**Breaking Change:** Starting with version 1.1.0, the extension no longer automatically creates a gateway instance during installation. This change gives users more control over when and how the scheduler starts.

**Migration from 1.0:**
- If upgrading from version 1.0, you must manually configure the gateway instance (see [Configuration](#configuration))
- Existing gateway instances continue to work without changes
- Jobs and configurations from v1.0 are fully compatible with v1.1+

**Why this change?**
- Allows for more granular control over scheduler initialization
- Enables cleaner separation between extension installation and activation
- Supports cases where you want the extension installed but scheduler not running
- Better aligns with Lucee's configuration-as-code philosophy

### v1.0.x (Legacy)

Automatically created and started a gateway instance named `quartz-task` on installation. This behavior is no longer supported in v1.1+.

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

- Lucee 6.2 (experimental) or Lucee 7 (fully supported)

## Installation

### Using the Lucee Administrator

1. Navigate to Extensions > Available Extensions
2. Find "Quartz Scheduler" in the list
3. Click "Install"

**Note:** Installing the extension does NOT automatically start a Quartz instance. You must configure it separately (see [Configuration](#configuration)).

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

### Step 1: Configure the Gateway Instance

After installing the extension, you must configure a gateway instance to enable the scheduler. You can do this in two ways:

**Option A: Via Lucee Administrator**

1. Go to **Server > Event Gateways > Gateway Instances**
2. Click "Create New Instance"
3. Select **Quartz Scheduler** as the gateway type
4. Set ID to `quartz-task`
5. Enable "Startup Mode: Automatic"
6. Configure the custom settings (see below)
7. Save

**Option B: Via .CFConfig.json**

Add this to your `.CFConfig.json`:

```json
{
  "gateways": {
    "quartz-task": {
      "cfcPath": "org.lucee.extension.quartz.QuartzGateway",
      "listenerCFCPath": "",
      "startupMode": "automatic",
      "custom": {
        "configFile": "{lucee-config}/quartz/config.json",
        "scheduler": "scheduler"
      },
      "readOnly": "false"
    }
  }
}
```

### Step 2: Configure Job and Storage Settings

The scheduler is configured via JSON, stored at:

```
{lucee-server}/lucee-server/context/quartz/config.json
```

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

## Documentation

Full documentation is available in the [Lucee docs](https://github.com/lucee/lucee-docs):

- [Quartz Scheduler](https://github.com/lucee/lucee-docs/blob/master/docs/recipes/scheduler-quartz.md) — overview, configuration reference, job types, and component jobs
- [Clustering with Quartz Scheduler](https://github.com/lucee/lucee-docs/blob/master/docs/recipes/scheduler-quartz-clustering.md) — database and Redis setup, primary/replica configuration, troubleshooting
- [Component-Based Jobs](https://github.com/lucee/lucee-docs/blob/master/docs/recipes/scheduler-quartz-component-jobs.md) — creating and configuring CFC-based jobs and listeners

## Feedback and Contribution

Issues and suggestions are welcome on the [issue tracker](../../issues).