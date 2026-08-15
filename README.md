# Gleam System Stats

A small full-stack Gleam application that displays the host machine's current
CPU and RAM utilization. The backend runs on Erlang/OTP with Wisp and Mist; the
browser client is built with Lustre.

## Project layout

- `server/` exposes HTTP endpoints and the system-statistics WebSocket.
- `client/` receives live statistics and renders them with Lustre.
- `shared/` contains the `SystemStats` type used by both applications.

The server uses Erlang's `os_mon` application through a small Erlang foreign
function interface in `server/src/system_stats/stats.erl`.

## Requirements

- Gleam
- Erlang/OTP with the `os_mon` application

The Lustre development command downloads and manages its frontend tooling when
needed.

## Run locally

Start the API server in one terminal:

```sh
cd server
gleam run
```

The API listens on `http://localhost:8000`.

Start the client development server in another terminal:

```sh
cd client
gleam run -m lustre/dev start
```

Open `http://localhost:1234` in a browser. The client connects directly to
`ws://localhost:8000/api/ws` during local development.

The initial connection is shown as `Checking`. If it cannot open within four
seconds, the UI reports the server as unreachable. Closed connections are
retried every 250 milliseconds and a successful connection returns the status
to `Alive`.

## Client configuration

Browser code cannot read operating-system environment variables directly. The
client therefore loads `/config.js` before its compiled JavaScript bundle and
reads `globalThis.__KILLMESTATS_CONFIG__` through a small JavaScript foreign
function interface.

The configuration source depends on how the application is run:

- Local development uses `client/assets/config.js`. Lustre copies this file to
  `client/dist/config.js` when starting or building the client. Edit the asset,
  not the generated file.
- Docker production uses `client/config.js.template`. At container startup,
  Nginx substitutes `API_HOST` and `MAX_CONNECTIONS` from the container
  environment and writes the resulting `config.js` into its web root.

`API_HOST` is the HTTP origin used for API requests. Leave it empty to use
`http://localhost:8000` with the local Lustre server or same-origin `/api`
requests behind Nginx. `MAX_CONNECTIONS` is the application-level ceiling for
the WebSocket connection control. Invalid or missing values use the fallback
defined in `client/src/ffi/config_ffi.mjs`.

For Docker, copy `.example.env` to `.env` and adjust the values before starting
the services:

```env
API_HOST=
MAX_CONNECTIONS=100
```

Then recreate the web container after changing runtime configuration:

```sh
docker compose up -d --force-recreate web
```

The application limit does not override limits imposed by the browser or
operating system. Firefox currently defaults to 200 concurrent WebSocket
sessions across the browser through its `network.websocket.max-connections`
preference. Consequently, the page may settle slightly below 200 when other
pages or browser features already hold WebSockets. This preference can be
inspected in `about:config`, but increasing it substantially can consume large
amounts of browser, OS, and server resources. See the
[Firefox networking defaults](https://searchfox.org/firefox-main/source/modules/libpref/init/all.js).

## WebSocket protocol

Connect to `GET /api/ws` using a WebSocket upgrade. The client sends this text
command whenever it wants the current sample:

```text
stats
```

The server replies with the latest reading and one cached sample per minute.
History is ordered from oldest to newest:

```json
{
  "data": {
    "latestStats": {
      "cpu_load": 12.5,
      "ram_load": 48.7,
      "ram_used_bytes": 8036286464,
      "ram_total_bytes": 17179869184
    },
    "timeStatsList": [
      {
        "timestamp_ms": 1700000000000,
        "systemStats": {
          "cpu_load": 11.8,
          "ram_load": 48.5,
          "ram_used_bytes": 8000000000,
          "ram_total_bytes": 17179869184
        }
      }
    ]
  }
}
```

Binary frames and unknown text commands are ignored. WebSocket routing happens
in Mist before ordinary requests are converted to Wisp requests because the
upgrade requires Mist's original connection value.

## API

### `GET /api/stats`

HTTP fallback for diagnostics and clients that cannot use WebSockets. It
returns the same CPU and RAM data as percentages in the `0.0` to `100.0`
range:

```json
{
  "cpu_load": 12.5,
  "ram_load": 48.7
}
```

CPU utilization comes from `cpu_sup`. RAM utilization is calculated from the
total and available system memory reported by `memsup`.

A reported value of `0.0` can be legitimate for an idle CPU. For RAM it may
indicate that `os_mon`/`memsup` was unavailable or could not read the operating
system's memory information; the server writes a warning when either metric is
zero.

## Development checks

Run these commands separately in `server/`, `client/`, and `shared/`:

```sh
gleam format --check src test
gleam check
gleam test
```

The current development configuration expects the client at
`http://localhost:1234` and the API at `http://localhost:8000`.

## Docker and Nginx

Run the complete application with:

```sh
docker compose up --build
```

Open `http://localhost:8080`. Nginx serves the compiled client and proxies the
entire `/api/` namespace to the Gleam server. The same proxy rule handles normal
HTTP and WebSocket upgrades, so new API routes do not require separate Nginx
locations.
