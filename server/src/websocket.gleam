import context
import gleam/erlang/process
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/option.{None, Some}
import live_users
import mist
import system_stats/payload
import websocket_hub

type SocketState {
  SocketState(hub_id: Int, live_user_registered: Bool)
}

/// Routes WebSocket upgrades before passing ordinary HTTP requests to Wisp.
/// Mist needs its original connection value to perform the upgrade.
pub fn handle(
  req: request.Request(mist.Connection),
  http_handler: fn(request.Request(mist.Connection)) ->
    Response(mist.ResponseData),
  context: context.Context,
) -> Response(mist.ResponseData) {
  case request.path_segments(req) {
    ["api", "ws"] ->
      mist.websocket(
        request: req,
        handler: fn(state, message, connection) {
          handle_message(state, message, connection, context)
        },
        on_init: fn(_connection) { init_primary_socket(context) },
        on_close: fn(state) {
          websocket_hub.unregister(context.ws_hub, state.hub_id)

          case state.live_user_registered {
            True -> live_users.remove(context.live_users_counter)
            False -> Nil
          }
        },
      )

    ["api", "load"] ->
      mist.websocket(
        request: req,
        handler: handle_load_message,
        on_init: fn(_connection) { #(Nil, None) },
        on_close: fn(_state) { Nil },
      )

    _ -> http_handler(req)
  }
}

fn init_primary_socket(context: context.Context) {
  let inbox = process.new_subject()
  let hub_id = websocket_hub.register(context.ws_hub, inbox)

  let selector =
    process.new_selector()
    |> process.select(inbox)

  #(SocketState(hub_id:, live_user_registered: False), Some(selector))
}

fn handle_message(
  state: SocketState,
  message: mist.WebsocketMessage(websocket_hub.Push),
  connection: mist.WebsocketConnection,
  context: context.Context,
) -> mist.Next(SocketState, websocket_hub.Push) {
  case message {
    mist.Text("client_stats") -> {
      let state = case state.live_user_registered {
        True -> state
        False -> {
          live_users.add(context.live_users_counter)
          SocketState(..state, live_user_registered: True)
        }
      }

      send_payload(connection, state, payload.encode(context))
    }
    mist.Text(_) -> mist.continue(state)

    mist.Binary(_) ->
      // The application protocol uses JSON text frames only.
      mist.continue(state)

    mist.Closed | mist.Shutdown -> mist.stop()
    mist.Custom(websocket_hub.StatsUpdated(payload)) ->
      send_payload(connection, state, payload)
  }
}

fn send_payload(
  connection: mist.WebsocketConnection,
  state: SocketState,
  payload: String,
) -> mist.Next(SocketState, websocket_hub.Push) {
  case mist.send_text_frame(connection, payload) {
    Ok(Nil) -> mist.continue(state)
    Error(_) -> mist.stop_abnormal("Could not send system stats")
  }
}

fn handle_load_message(
  state: Nil,
  message: mist.WebsocketMessage(Nil),
  _connection: mist.WebsocketConnection,
) -> mist.Next(Nil, Nil) {
  case message {
    mist.Text(_) | mist.Binary(_) | mist.Custom(_) -> mist.continue(state)
    mist.Closed | mist.Shutdown -> mist.stop()
  }
}
