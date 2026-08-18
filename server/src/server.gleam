import stats_sampler
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

  stats_sampler.start(context)

  let http_handler = wisp_mist.handler(router.handle_request, secret_key_base)

  // WebSocket upgrades need Mist's connection value before Wisp consumes the request.
  let handler = fn(request) { websocket.handle(request, http_handler, context) }

  let assert Ok(_) =
    handler
    |> mist.new
    |> mist.bind("::")
    |> mist.port(8000)
    |> mist.start

  log.info("Server started")
  process.sleep_forever()
}
