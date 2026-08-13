import gleam/http/request
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{None}
import mist

import sysstats
import system_stats/stats

/// Routes WebSocket upgrades before passing ordinary HTTP requests to Wisp.
/// Mist needs its original connection value to perform the upgrade.
pub fn handle(
  req: request.Request(mist.Connection),
  http_handler: fn(request.Request(mist.Connection)) ->
    Response(mist.ResponseData),
) -> Response(mist.ResponseData) {
  case request.path_segments(req) {
    ["api", "ws"] ->
      mist.websocket(
        request: req,
        handler: handle_message,
        on_init: fn(_connection) { #(Nil, None) },
        on_close: fn(_state) { Nil },
      )

    _ -> http_handler(req)
  }
}

fn handle_message(
  state: Nil,
  message: mist.WebsocketMessage(Nil),
  connection: mist.WebsocketConnection,
) -> mist.Next(Nil, Nil) {
  case message {
    mist.Text("stats") -> send_stats(connection, state)
    mist.Text(_) -> mist.continue(state)

    mist.Binary(_) ->
      // The application protocol uses JSON text frames only.
      mist.continue(state)

    mist.Closed | mist.Shutdown -> mist.stop()
    mist.Custom(_) -> mist.continue(state)
  }
}

fn send_stats(
  connection: mist.WebsocketConnection,
  state: Nil,
) -> mist.Next(Nil, Nil) {
  let payload =
    stats.get_system_stats()
    |> sysstats.to_json
    |> json.to_string

  case mist.send_text_frame(connection, payload) {
    Ok(Nil) -> mist.continue(state)
    Error(_) -> mist.stop_abnormal("Could not send system stats")
  }
}
