import api/api_client
import api/error
import api/system_stats
import app/state
import ffi/timer
import gleam/io
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleam/uri.{Uri}
import log
import lustre/effect.{type Effect}
import lustre_websocket as websocket
import sysstats

const poll_interval_ms = 1000

const reconnect_interval_ms = 250

const connection_timeout_ms = 4000

const panic_log = "EROR function=\"panic_program\" message=\"`panic` expression evaluated.\" module=\"router\" file=\"src/router.gleam\" gleam_error=Panic class=Errored"

pub fn update(
  model: state.Model,
  msg: state.Msg,
) -> #(state.Model, Effect(state.Msg)) {
  case msg {
    state.SocketEvent(websocket.InvalidUrl) -> {
      io.print_error("Invalid WebSocket URL\n")
      #(
        state.Model(
          ..model,
          server_status: system_stats.ServerUnreachable("Invalid WebSocket URL"),
        ),
        effect.none(),
      )
    }
    state.SocketEvent(websocket.OnOpen(socket)) -> {
      #(
        state.Model(
          ..model,
          socket: Some(socket),
          connection_timed_out: False,
          server_status: system_stats.Alive,
        ),
        websocket.send(socket, "stats"),
      )
    }
    state.SocketEvent(websocket.OnTextMessage(payload)) -> {
      case json.parse(payload, sysstats.decoder()) {
        Ok(stats) -> #(
          state.Model(..model, stats: stats, server_status: system_stats.Alive),
          schedule_next_fetch(),
        )
        Error(err) -> {
          log.error(
            "Invalid SystemStats WebSocket message: "
            <> error.json_decode_message(err),
          )
          #(model, schedule_next_fetch())
        }
      }
    }
    state.Tick -> {
      case model.socket {
        Some(socket) -> #(model, websocket.send(socket, "stats"))

        None -> #(model, connect_websocket())
      }
    }
    state.ConnectionTimedOut -> {
      case model.socket {
        None -> #(
          state.Model(
            ..model,
            connection_timed_out: True,
            server_status: system_stats.ServerUnreachable(
              "WebSocket connection timed out",
            ),
          ),
          effect.none(),
        )
        Some(_) -> #(model, effect.none())
      }
    }
    state.UserClickedPanic -> #(
      state.Model(..model, terminal_lines: [panic_log, ..model.terminal_lines]),
      panic_server(),
    )

    state.SocketEvent(websocket.OnBinaryMessage(_)) -> #(model, effect.none())
    state.SocketEvent(websocket.OnClose(reason)) -> {
      io.print_error("WebSocket closed: " <> string.inspect(reason) <> "\n")

      let server_status = case model.connection_timed_out {
        True -> system_stats.ServerUnreachable("WebSocket disconnected")
        False -> system_stats.Checking
      }

      #(
        state.Model(..model, socket: None, server_status: server_status),
        schedule_reconnect(),
      )
    }
  }
}

pub fn websocket_url() -> String {
  // Selecting ws_url depending on env (dev/prod)
  case websocket.page_uri() {
    Ok(uri) if uri.port == Some(1234) ->
      Uri(
        ..uri,
        scheme: Some("ws"),
        port: Some(8000),
        path: "/api/ws",
        query: None,
        fragment: None,
      )
      |> uri.to_string

    _ -> "/api/ws"
  }
}

pub fn connect_websocket() -> Effect(state.Msg) {
  // The timeout is not cancelled; it is harmless after the socket opens.
  effect.batch([
    websocket.init(websocket_url(), state.SocketEvent),
    timer.after(connection_timeout_ms, state.ConnectionTimedOut),
  ])
}

fn schedule_next_fetch() -> Effect(state.Msg) {
  timer.after(poll_interval_ms, state.Tick)
}

fn schedule_reconnect() -> Effect(state.Msg) {
  timer.after(reconnect_interval_ms, state.Tick)
}

fn panic_server() -> Effect(state.Msg) {
  effect.from(fn(_dispatch) {
    api_client.post("/api/panic")
    Nil
  })
}
