# Quartz extension with MCP interface in Docker

Lucee with the Quartz extension, a dummy job that runs every 10 seconds, and a page that talks to the
[MCP interface](../../README.md#mcp-interface) of the extension.

## Run

Build the extension (the image takes it from `target/`), then start the container:

```sh
mvn clean install -DskipTests      # in the repository root
cd examples/docker
docker compose up -d --build
```

Open <http://localhost:8857/>.

```sh
docker compose logs -f             # the dummy job prints a line every 10 seconds
docker compose down
```

The Lucee Administrator is at <http://localhost:8857/lucee/admin/server.cfm> (password `qwerty`).

## What is in here

| File | Purpose |
|---|---|
| `Dockerfile` | Lucee image, installs the `.lex` from `target/` through the deploy folder. Another Lucee image: `--build-arg LUCEE_IMAGE=...` |
| `docker-compose.yml` | builds the image from the repository root, port `8857` |
| `config.json` | scheduler config: the `mcp` permission, the `bearer` authenticator and two dummy jobs, one of them paused |
| `lucee-config.json` | Lucee config, sends the scheduler log to the console |
| `www/index.cfm` | the try page |

The extension starts its scheduler on installation (event gateway `quartz-task`), the config file is
selected with `QUARTZ_CONFIGFILE` (set in the `Dockerfile`).

## The try page

`www/index.cfm` is an MCP client. It posts JSON-RPC to `/lucee/quartz/mcp/` on the server side, with the
secret from the environment, so the secret never reaches the browser. It shows the scheduler metadata and
the triggers and lets you pause, unpause, execute and delete jobs, add a dummy job, and send a raw
JSON-RPC request, for example without a token, to see how the interface rejects it.

## Call it yourself

The secret is `quartz-example-secret`, change it with the environment variable `QUARTZ_MCP_SECRET`.

```sh
curl -s -X POST http://localhost:8857/lucee/quartz/mcp/ \
  -H "Authorization: Bearer quartz-example-secret" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"quartz_listJobs","arguments":{}}}'
```

Connect an MCP client (here the format of Claude Code / Cursor):

```json
{
  "mcpServers": {
    "quartz": {
      "url": "http://localhost:8857/lucee/quartz/mcp/",
      "headers": { "Authorization": "Bearer quartz-example-secret" }
    }
  }
}
```

Things to try in `config.json` (rebuild the image afterwards):

- `"mcp": "read"`: the write tools disappear from `tools/list` and calls to them are refused
- remove `mcp`: every request is rejected
- `"mcpAuthenticator": { "component": "none" }`: no secret needed (never do that on a reachable server)
- `settings.readSecret`: a second secret that only gets read access

The scheduler writes changes (jobs added, paused, deleted) back to `/opt/quartz/config.json` inside the
container, they are gone when the container is removed. Mount a volume on `/opt/quartz` to keep them.
