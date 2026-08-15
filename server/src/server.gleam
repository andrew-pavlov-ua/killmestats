import cache
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

  let assert Ok(table) = cache.create_cache()
  let context = cache.Context(table)

  let http_handler = wisp_mist.handler(router.handle_request, secret_key_base)

  let handler = fn(request) { websocket.handle(request, http_handler, context) }

  let assert Ok(_) =
    handler
    |> mist.new
    // |> mist.bind("0.0.0.0")
    |> mist.bind("::")
    |> mist.port(8000)
    |> mist.start

  log.info("Server started")
  process.sleep_forever()
}
