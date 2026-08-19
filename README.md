# Gleam System Stats

A Gleam dashboard for the host's CPU and RAM usage. The server runs on
Erlang/OTP with Wisp and Mist. The browser client uses Lustre and Chart.js.

## Project layout

- `server/` exposes the HTTP API and WebSocket, samples once an hour, and keeps
  the latest 24 hours in ETS and PostgreSQL.
- `client/` receives live statistics and renders the dashboard with Lustre and
  Chart.js.
- `shared/` contains the statistics and WebSocket payload types used by both
  applications.

The server uses Erlang's `os_mon` application through a small Erlang foreign
function interface in `server/src/system_stats/stats.erl`.

## Requirements

- Gleam
- Erlang/OTP with the `os_mon` application
- Docker with Docker Compose for the production server
- Nginx for serving the production client

The Lustre development command downloads its frontend tooling when needed.

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
operating system.

## WebSocket protocol

Connect to `GET /api/ws` using a WebSocket upgrade. The client sends this text
command whenever it wants the current sample:

```text
stats
```

The server replies with the latest reading and the cached history. A server-side
sampler records one point at each hour boundary, even when no browser is
connected. Samples older than 24 hours are removed, and history is ordered from
oldest to newest:

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
returns CPU and RAM utilization as percentages in the `0.0` to `100.0` range,
along with used and total RAM in bytes:

```json
{
  "cpu_load": 12.5,
  "ram_load": 48.7,
  "ram_used_bytes": 8036286464,
  "ram_total_bytes": 17179869184
}
```

CPU utilization comes from `cpu_sup`. RAM utilization is calculated from the
total and available system memory reported by `memsup`.

A reported CPU value of `0.0` can be legitimate when the machine is idle, so it
does not produce a warning by itself. Failures returned by `os_mon`/`cpu_sup`
are logged by the Erlang adapter. A RAM value of `0.0` may indicate that
`os_mon`/`memsup` was unavailable or could not read the operating system's
memory information, and the server writes a warning for that value.

## Development checks

Run these commands separately in `server/`, `client/`, and `shared/`:

```sh
gleam format --check src test
gleam check
gleam test
```

The current development configuration expects the client at
`http://localhost:1234` and the API at `http://localhost:8000`.

GitHub Actions runs these checks for `shared`, `server`, and `client` on pushes
to `master` or `main`, and on pull requests.

## Production deployment

The server runs in Docker. Build and start it from the repository root:

```sh
docker compose up -d --build server
```

Build the client and copy the contents of `client/dist` to `/var/www/html`:

```sh
make client-deploy
```

`client-build` only creates the static files. `client-deploy` runs that build
and then copies `client/dist/.` with `sudo`, preserving dotfiles and copying the
directory contents rather than nesting a `dist` directory under the web root.

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

After a successful `test` workflow on `master`, the `deploy` workflow performs
both commands on a Linux self-hosted runner. The runner host must have Docker,
Docker Compose, Nginx, and passwordless permission for the `sudo cp` used by
`make client-deploy`. The workflow targets an Ubuntu 22 compatible Erlang build
through `ImageOS: ubuntu22`; the host itself may be Debian.
