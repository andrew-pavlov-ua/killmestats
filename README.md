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

The initial connection is shown as `Checking`. If it cannot open within five
seconds, the UI reports the server as unreachable. Closed connections are
retried every 250 milliseconds and a successful connection returns the status
to `Alive`.

## WebSocket protocol

Connect to `GET /api/ws` using a WebSocket upgrade. The client sends this text
command whenever it wants the current sample:

```text
stats
```

The server replies with a JSON text frame:

```json
{"cpu_load":12.5,"ram_load":48.7}
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
