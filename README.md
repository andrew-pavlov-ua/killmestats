# killmestats

A small Gleam dashboard for watching a host's CPU and RAM usage. The server
runs on Erlang/OTP with Wisp and Mist; the browser client uses Lustre and
Chart.js.

## Project layout

- `server/` serves the API and WebSockets and keeps 24 hours of hourly samples
  in ETS and PostgreSQL.
- `client/` renders live and historical statistics.
- `shared/` contains the types used by both applications.

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

The UI reports the server as unreachable if the initial connection cannot open
within four seconds. Closed connections are retried every 250 milliseconds.

## Client configuration

Local development connects directly to `http://localhost:8000`. In production,
the client uses same-origin `/api` requests and Nginx proxies them to
`127.0.0.1:8000`. These defaults live in `client/src/config.gleam`; the static
client does not need a production `.env` file.

The load control allows up to 500 extra WebSockets. New connections are opened
25 milliseconds apart so a large batch does not block the main connection.
Browser and operating-system limits still apply.

The GitHub badge requests the repository's star count once when the client
starts. It falls back to a plain `Star` label if the request fails.

## WebSocket protocol

The primary client connects to `GET /api/ws` and sends `client_stats` once. The
server replies with an initial snapshot and broadcasts fresh statistics every
second. Extra load-test connections use `/api/load` and do not receive those
broadcasts.

An hourly sampler records chart history even when no browser is connected.
Samples older than 24 hours are removed, and history is ordered from oldest to
newest:

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
    ],
    "liveUsers": 1
  }
}
```

Binary frames and unknown text commands are ignored. Mist handles the upgrade
before ordinary requests are passed to Wisp.

## API

### `GET /api/stats`

Returns CPU and RAM utilization as percentages, plus used and total RAM in
bytes:

```json
{
  "cpu_load": 12.5,
  "ram_load": 48.7,
  "ram_used_bytes": 8036286464,
  "ram_total_bytes": 17179869184
}
```

CPU utilization comes from `cpu_sup`; RAM values come from `memsup`.

### `POST /api/panic`

Deliberately panics inside the request handler. Wisp catches the panic and
returns `500 Internal Server Error`; the server process stays up. The dashboard's
`Probe the System` button calls this endpoint.

## Development checks

Run these commands separately in `server/`, `client/`, and `shared/`:

```sh
gleam format --check src test
gleam check
gleam test
```

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

`client-build` only creates the static files. `client-deploy` also copies
`client/dist/.` to the web root.

Install the project Nginx configuration the first time, or whenever
`client/nginx.conf` changes:

```sh
make nginx-install
```

`nginx-install` replaces the Debian/Ubuntu default site, checks the
configuration, and reloads Nginx. Nginx serves `/var/www/html` and proxies
`/api/` requests and WebSocket upgrades to `127.0.0.1:8000`.

For later updates, rebuild only the part that changed:

```sh
# Backend
docker compose up -d --build server

# Frontend
make client-deploy
```

After a successful `test` workflow on `master`, the `deploy` workflow runs both
commands on a Linux self-hosted runner. The host needs Docker, Docker Compose,
Nginx, and passwordless permission for the `sudo cp` used by
`make client-deploy`.
