import cache
import db/postgres
import gleam/erlang/process
import gleam/option
import log
import mist
import router
import stats_sampler
import websocket
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(db) = postgres.init_db()
  let assert Ok(table) = cache.init_cache(option.Some(db))

  let context = cache.Context(table, db)

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
