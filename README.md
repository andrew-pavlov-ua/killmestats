# Gleam System Stats

A small full-stack Gleam application that displays the host machine's current
CPU and RAM utilization. The backend runs on Erlang/OTP with Wisp and Mist; the
browser client is built with Lustre.

## Project layout

- `server/` exposes the system statistics HTTP API.
- `client/` fetches the statistics and renders them in the browser.
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

Open `http://localhost:1234` in a browser. The client fetches statistics on
startup and whenever **GET SERVER STATS** is clicked.

## API

### `GET /api/stats`

Returns CPU and RAM utilization as percentages in the `0.0` to `100.0` range:

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
