import api/api_client
import api/error
import app/extra_websocket as su
import app/state
import data
import ffi/timer
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import log
import lustre/effect.{type Effect}
import lustre_websocket as websocket
import ui/charts

const poll_interval_ms = 1000

const reconnect_interval_ms = 250

const connection_timeout_ms = 4000

const panic_log = "EROR function=\"panic_program\" message=\"`panic` expression evaluated.\" module=\"router\" file=\"src/router.gleam\" gleam_error=Panic class=Errored"

pub fn update(
  model: state.Model,
  msg: state.Msg,
) -> #(state.Model, Effect(state.Msg)) {
  case msg {
    state.AddConnection -> su.add_connection(model)
    state.RemoveConnection -> su.remove_connection(model)
    state.SetConnectionCount(value) -> su.set_connection_count(model, value)
    state.ExtraSocketEvent(id, event) ->
      su.update_extra_socket(model, id, event)
    state.ExtraTick(id) -> su.poll_extra_socket(model, id)
    state.SocketEvent(id, event) if id != model.primary_connection_id ->
      case event {
        websocket.OnOpen(socket) -> #(model, websocket.close(socket))
        _ -> #(model, effect.none())
      }
    state.SocketEvent(_, websocket.InvalidUrl) -> {
      io.print_error("Invalid WebSocket URL\n")
      #(
        state.Model(
          ..model,
          server_status: state.ServerUnreachable("Invalid WebSocket URL"),
        ),
        effect.none(),
      )
    }
    state.SocketEvent(_, websocket.OnOpen(socket)) -> {
      #(
        state.Model(
          ..model,
          socket: Some(socket),
          connection_timed_out: False,
          server_status: state.Alive,
        ),
        websocket.send(socket, "stats"),
      )
    }
    state.SocketEvent(id, websocket.OnTextMessage(payload)) -> {
      case json.parse(payload, data.decoder()) {
        Ok(data) -> {
          let cpu_history =
            charts.values(
              data.time_stats_list,
              fn(sample) { sample.stats.cpu_load },
              data.latest_stats.cpu_load,
            )
          let ram_history =
            charts.values(
              data.time_stats_list,
              fn(sample) { sample.stats.ram_load },
              data.latest_stats.ram_load,
            )
          let timestamps =
            list.map(data.time_stats_list, fn(sample) { sample.timestamp_ms })

          #(
            state.Model(
              ..model,
              stats: data.latest_stats,
              server_status: state.Alive,
            ),
            effect.batch([
              schedule_next_fetch(id),
              charts.render(cpu_history, ram_history, timestamps),
            ]),
          )
        }
        Error(err) -> {
          log.error(
            "Invalid stats WebSocket message: "
            <> error.json_decode_message(err),
          )
          #(model, schedule_next_fetch(id))
        }
      }
    }
    state.Tick(id) if id != model.primary_connection_id -> #(
      model,
      effect.none(),
    )
    state.Tick(id) -> {
      case model.socket {
        Some(socket) -> #(model, websocket.send(socket, "stats"))

        None -> #(model, connect_websocket(id))
      }
    }
    state.ConnectionTimedOut(id) if id != model.primary_connection_id -> #(
      model,
      effect.none(),
    )
    state.ConnectionTimedOut(id) -> {
      case model.socket {
        None -> {
          let next_id = id + 1
          #(
            state.Model(
              ..model,
              primary_connection_id: next_id,
              connection_timed_out: True,
              server_status: state.ServerUnreachable(
                "WebSocket connection timed out",
              ),
            ),
            schedule_reconnect(next_id),
          )
        }
        Some(_) -> #(model, effect.none())
      }
    }
    state.UserClickedPanic -> #(
      state.Model(..model, terminal_lines: [panic_log, ..model.terminal_lines]),
      panic_server(),
    )

    state.SocketEvent(_, websocket.OnBinaryMessage(_)) -> #(
      model,
      effect.none(),
    )
    state.SocketEvent(id, websocket.OnClose(reason)) -> {
      io.print_error("WebSocket closed: " <> string.inspect(reason) <> "\n")

      let server_status = case model.connection_timed_out {
        True -> state.ServerUnreachable("WebSocket disconnected")
        False -> state.Checking
      }

      let next_id = id + 1
      #(
        state.Model(
          ..model,
          socket: None,
          primary_connection_id: next_id,
          server_status: server_status,
        ),
        schedule_reconnect(next_id),
      )
    }
  }
}

pub fn connect_websocket(id: Int) -> Effect(state.Msg) {
  // The timeout is not cancelled; it is harmless after the socket opens.
  effect.batch([
    websocket.init(su.websocket_url(), fn(event) {
      state.SocketEvent(id, event)
    }),
    timer.after(connection_timeout_ms, state.ConnectionTimedOut(id)),
  ])
}

fn schedule_next_fetch(id: Int) -> Effect(state.Msg) {
  timer.after(poll_interval_ms, state.Tick(id))
}

fn schedule_reconnect(id: Int) -> Effect(state.Msg) {
  timer.after(reconnect_interval_ms, state.Tick(id))
}

fn panic_server() -> Effect(state.Msg) {
  effect.from(fn(_dispatch) {
    api_client.post("/api/panic")
    Nil
  })
}
