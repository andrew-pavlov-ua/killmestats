import gleam/erlang/process
import log
import mist
import router
import websocket
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let http_handler = wisp_mist.handler(router.handle_request, secret_key_base)

  let handler = fn(request) { websocket.handle(request, http_handler) }

  let assert Ok(_) =
    handler
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start

  log.info("Server started")
  process.sleep_forever()
}
