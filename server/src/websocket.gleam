import cache
import data
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{None}
import live_users
import mist

import system_stats/stats

/// Routes WebSocket upgrades before passing ordinary HTTP requests to Wisp.
/// Mist needs its original connection value to perform the upgrade.
pub fn handle(
  req: request.Request(mist.Connection),
  http_handler: fn(request.Request(mist.Connection)) ->
    Response(mist.ResponseData),
  context: cache.Context,
  live_user_counter: live_users.Counter,
) -> Response(mist.ResponseData) {
  case request.path_segments(req) {
    ["api", "ws"] ->
      mist.websocket(
        request: req,
        handler: fn(state, message, connection) {
          handle_message(state, message, connection, context, live_user_counter)
        },
        on_init: fn(_connection) { #(False, None) },
        on_close: fn(registered) {
          case registered {
            True -> live_users.remove(live_user_counter)
            False -> Nil
          }
        },
      )

    _ -> http_handler(req)
  }
}

fn handle_message(
  registered: Bool,
  message: mist.WebsocketMessage(Bool),
  connection: mist.WebsocketConnection,
  context: cache.Context,
  live_user_counter: live_users.Counter,
) -> mist.Next(Bool, Bool) {
  case message {
    mist.Text("client_stats") -> {
      let count = case registered {
        True -> live_users.current(live_user_counter)
        False -> live_users.add(live_user_counter)
      }
      send_stats(connection, True, context, count)
    }
    mist.Text("stats") ->
      send_stats(
        connection,
        registered,
        context,
        live_users.current(live_user_counter),
      )
    mist.Text(_) -> mist.continue(registered)

    mist.Binary(_) ->
      // The application protocol uses JSON text frames only.
      mist.continue(registered)

    mist.Closed | mist.Shutdown -> mist.stop()
    mist.Custom(_) -> mist.continue(registered)
  }
}

fn send_stats(
  connection: mist.WebsocketConnection,
  registered: Bool,
  context: cache.Context,
  live_user_count: Int,
) -> mist.Next(Bool, Bool) {
  let stats = stats.get_system_stats()

  let time_stats_list = cache.read_whole_cache(context.cache)
  let data =
    data.Data(
      latest_stats: stats,
      time_stats_list: time_stats_list,
      live_users: live_user_count,
    )

  let payload =
    data
    |> data.to_json
    |> json.to_string

  case mist.send_text_frame(connection, payload) {
    Ok(Nil) -> mist.continue(registered)
    Error(_) -> mist.stop_abnormal("Could not send system stats")
  }
}
