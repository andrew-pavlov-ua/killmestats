import app/state
import config
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/uri.{Uri}
import lustre/effect.{type Effect}
import lustre_websocket as websocket

pub fn set_connection_count(model: state.Model, value: String) {
  set_connection_count_at(model, value, load_websocket_url())
}

pub fn set_connection_count_at(model: state.Model, value: String, url: String) {
  case int.parse(value) {
    Error(_) -> #(model, effect.none())
    Ok(requested) -> {
      let target =
        int.clamp(requested, min: 0, max: config.max_socket_connections())
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
  let current = list.length(model.connections)

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
  add_connection_at(model, load_websocket_url())
}

pub fn add_connection_at(model: state.Model, url: String) {
  let total = list.length(model.connections)

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
        // A removed connection can still finish opening after its close was requested.
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
          #(state.Model(..model, connections: connections), effect.none())
        }
      }
    }
    websocket.OnTextMessage(_) -> #(model, effect.none())
    websocket.OnBinaryMessage(_) -> #(model, effect.none())
    websocket.InvalidUrl -> #(remove_extra_connection(model, id), effect.none())
    websocket.OnClose(_) -> #(remove_extra_connection(model, id), effect.none())
  }
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

pub fn websocket_url() -> String {
  websocket_url_for("/api/ws")
}

pub fn load_websocket_url() -> String {
  websocket_url_for("/api/load")
}

fn websocket_url_for(path: String) -> String {
  // Lustre's dev server and the API run on separate ports during local development.
  case websocket.page_uri() {
    Ok(uri) if uri.port == Some(1234) ->
      Uri(
        ..uri,
        scheme: Some("ws"),
        port: Some(8000),
        path: path,
        query: None,
        fragment: None,
      )
      |> uri.to_string

    _ -> path
  }
}
