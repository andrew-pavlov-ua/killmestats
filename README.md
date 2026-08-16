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
- Docker with Docker Compose for the production server
- Nginx for serving the production client

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

Local development connects directly to `http://localhost:8000`. The production
client uses same-origin `/api` requests, which host Nginx proxies to the server
on `127.0.0.1:8000`. The default WebSocket connection limit is 1000. These
defaults are defined in `client/src/config.gleam`; no production `.env`
file is required for the client.

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

## Production deployment

The server runs in Docker. Build and start it from the repository root:

```sh
docker compose up -d --build server
```

Build the client and copy its static files to `/var/www/html`:

```sh
make client-deploy
```

Install the project Nginx configuration the first time, or whenever
`client/nginx.conf` changes:

```sh
make nginx-install
```

`nginx-install` replaces the Debian/Ubuntu default site, checks the
configuration, and reloads Nginx. Nginx serves `/var/www/html` and proxies the
entire `/api/` namespace to `127.0.0.1:8000`. The same location supports normal
HTTP requests and WebSocket upgrades.

Open the host running Nginx in a browser. Port 8080 is no longer used by the
frontend.

For later updates, rebuild only the part that changed:

```sh
# Backend
docker compose up -d --build server

# Frontend
make client-deploy
```
