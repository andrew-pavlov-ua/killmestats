import api/error
import app/state
import config
import ffi/timer
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/uri.{Uri}
import log
import lustre/effect.{type Effect}
import lustre_websocket as websocket
import sysstats

const poll_interval_ms = 1000

const connection_timeout_ms = 4000

// Separate funcs for testability
pub fn set_connection_count(model: state.Model, value: String) {
  set_connection_count_at(model, value, websocket_url())
}

pub fn set_connection_count_at(model: state.Model, value: String, url: String) {
  case int.parse(value) {
    Error(_) -> #(model, effect.none())
    Ok(requested) -> {
      let target =
        int.clamp(requested, min: 1, max: config.max_socket_connections())
      resize_connections(model, target, [], url)
    }
  }
}

pub fn resize_connections(
  model: state.Model,
  target: Int,
  effects: List(Effect(state.Msg)),
  url: String,
) {
  let current = list.length(model.connections) + 1

  case current == target, current < target {
    True, _ -> #(model, effect.batch(effects))
    False, True -> {
      let #(next_model, next_effect) = add_connection_at(model, url)
      resize_connections(next_model, target, [next_effect, ..effects], url)
    }
    False, False -> {
      let #(next_model, next_effect) = remove_connection(model)
      resize_connections(next_model, target, [next_effect, ..effects], url)
    }
  }
}

pub fn add_connection(model: state.Model) {
  add_connection_at(model, websocket_url())
}

pub fn add_connection_at(model: state.Model, url: String) {
  let total = list.length(model.connections) + 1

  case total >= config.max_socket_connections() {
    True -> #(model, effect.none())
    False -> {
      let id = model.next_connection_id
      #(
        state.Model(
          ..model,
          connections: [state.Connecting(id), ..model.connections],
          next_connection_id: id + 1,
        ),
        websocket.init(url, fn(event) { state.ExtraSocketEvent(id, event) }),
      )
    }
  }
}

pub fn remove_connection(model: state.Model) {
  case model.connections {
    [] -> #(model, effect.none())
    [connection, ..rest] -> {
      let close = case connection {
        state.Connecting(_) -> effect.none()
        state.Connected(_, socket) -> websocket.close(socket)
      }
      #(state.Model(..model, connections: rest), close)
    }
  }
}

pub fn update_extra_socket(
  model: state.Model,
  id: Int,
  event: websocket.WebSocketEvent,
) {
  case event {
    websocket.OnOpen(socket) -> {
      let is_expected =
        list.any(model.connections, fn(connection) {
          case connection {
            state.Connecting(connection_id) -> connection_id == id
            state.Connected(_, _) -> False
          }
        })

      case is_expected {
        False -> #(model, websocket.close(socket))
        True -> {
          let connections =
            list.map(model.connections, fn(connection) {
              case connection {
                state.Connecting(connection_id) if connection_id == id ->
                  state.Connected(id, socket)
                _ -> connection
              }
            })
          #(
            state.Model(..model, connections: connections),
            websocket.send(socket, "stats"),
          )
        }
      }
    }
    websocket.OnTextMessage(payload) ->
      // Other extra socket's payload could be here, but for now it's the same as primary has

      case connection_exists(model.connections, id) {
        False -> #(model, effect.none())
        True ->
          case json.parse(payload, sysstats.decoder()) {
            Ok(stats) -> #(
              state.Model(..model, stats: stats, server_status: state.Alive),
              schedule_extra_fetch(id),
            )
            Error(err) -> {
              log.error(
                "Invalid SystemStats WebSocket message: "
                <> error.json_decode_message(err),
              )
              #(model, schedule_extra_fetch(id))
            }
          }
      }
    websocket.OnBinaryMessage(_) -> #(model, effect.none())
    websocket.InvalidUrl -> #(remove_extra_connection(model, id), effect.none())
    websocket.OnClose(_) -> #(remove_extra_connection(model, id), effect.none())
  }
}

pub fn poll_extra_socket(model: state.Model, id: Int) {
  case find_connected_socket(model.connections, id) {
    None -> #(model, effect.none())
    Some(socket) -> #(model, websocket.send(socket, "stats"))
  }
}

fn find_connected_socket(
  connections: List(state.Connection),
  id: Int,
) -> Option(websocket.WebSocket) {
  case connections {
    [] -> None
    [state.Connected(connection_id, socket), ..] if connection_id == id ->
      Some(socket)
    [_, ..rest] -> find_connected_socket(rest, id)
  }
}

fn connection_exists(connections: List(state.Connection), id: Int) -> Bool {
  list.any(connections, fn(connection) {
    case connection {
      state.Connecting(connection_id) | state.Connected(connection_id, _) ->
        connection_id == id
    }
  })
}

fn remove_extra_connection(model: state.Model, id: Int) -> state.Model {
  state.Model(
    ..model,
    connections: list.filter(model.connections, fn(connection) {
      case connection {
        state.Connecting(connection_id) | state.Connected(connection_id, _) ->
          connection_id != id
      }
    }),
  )
}

pub fn connect_websocket(id: Int) -> Effect(state.Msg) {
  // The timeout is not cancelled; it is harmless after the socket opens.
  effect.batch([
    websocket.init(websocket_url(), fn(event) { state.SocketEvent(id, event) }),
    timer.after(connection_timeout_ms, state.ConnectionTimedOut(id)),
  ])
}

fn schedule_extra_fetch(id: Int) -> Effect(state.Msg) {
  timer.after(poll_interval_ms, state.ExtraTick(id))
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
