import cache
import context
import db/queries
import gleam/erlang/process
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/option.{type Option, None, Some}
import live_users
import log
import mist
import system_stats/payload
import websocket_hub

type SocketState {
  SocketState(
    hub_id: Int,
    live_user_registered: Bool,
    returning_visitor: Bool,
    ip_address: Option(String),
  )
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
    ["api", "ws"] -> {
      let #(ip_address, returning_visitor) = lookup_visitor(req, context)

      mist.websocket(
        request: req,
        handler: fn(state, message, connection) {
          handle_message(state, message, connection, context)
        },
        on_init: fn(_connection) {
          init_primary_socket(context, returning_visitor, ip_address)
        },
        on_close: fn(state) {
          websocket_hub.unregister(context.ws_hub, state.hub_id)

          case state.live_user_registered {
            True -> live_users.remove(context.live_users_counter)
            False -> Nil
          }
        },
      )
    }

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

fn init_primary_socket(
  context: context.Context,
  returning_visitor: Bool,
  ip_address: Option(String),
) {
  let inbox = process.new_subject()
  let hub_id = websocket_hub.register(context.ws_hub, inbox)

  let selector =
    process.new_selector()
    |> process.select(inbox)

  #(
    SocketState(
      hub_id:,
      live_user_registered: False,
      returning_visitor:,
      ip_address:,
    ),
    Some(selector),
  )
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

      let encoded = payload.encode(context, state.returning_visitor)

      case mist.send_text_frame(connection, encoded) {
        Ok(Nil) -> mist.continue(record_first_visit(state, context))
        Error(_) -> mist.stop_abnormal("Could not send system stats")
      }
    }
    mist.Text(_) -> mist.continue(state)

    mist.Binary(_) ->
      // The application protocol uses JSON text frames only.
      mist.continue(state)

    mist.Closed | mist.Shutdown -> mist.stop()
    mist.Custom(websocket_hub.StatsUpdated) ->
      send_payload(
        connection,
        state,
        payload.encode(context, state.returning_visitor),
      )
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

fn lookup_visitor(
  req: request.Request(mist.Connection),
  context: context.Context,
) -> #(Option(String), Bool) {
  case client_ip(req) {
    Ok(ip_address) -> {
      let returning_visitor = case
        queries.user_exists_ip(context.db, ip_address)
      {
        Ok(result) -> result
        Error(error) -> {
          log.error(
            "Failed to check whether the client IP is registered: "
            <> cache.query_error_to_string(error),
          )
          True
        }
      }

      #(Some(ip_address), returning_visitor)
    }
    Error(_) -> #(None, True)
  }
}

fn record_first_visit(
  state: SocketState,
  context: context.Context,
) -> SocketState {
  case state.returning_visitor, state.ip_address {
    False, Some(ip_address) ->
      case queries.insert_user_ip(context.db, ip_address) {
        Ok(Nil) -> SocketState(..state, returning_visitor: True)
        Error(error) -> {
          log.error(
            "Failed to register the client IP: "
            <> cache.query_error_to_string(error),
          )
          state
        }
      }
    _, _ -> state
  }
}

fn client_ip(req: request.Request(mist.Connection)) -> Result(String, Nil) {
  case request.get_header(req, "x-real-ip") {
    Ok(ip) -> Ok(ip)

    Error(_) ->
      case mist.get_connection_info(req.body) {
        Ok(info) ->
          info.ip_address
          |> mist.ip_address_to_string
          |> Ok

        Error(_) -> {
          log.warning("Client IP unavailable")
          Error(Nil)
        }
      }
  }
}
