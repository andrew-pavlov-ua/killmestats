import cache
import context
import db/postgres
import gleam/erlang/process
import gleam/option
import live_users
import log
import mist
import router
import stats_sampler
import system_stats/stats_scheduler
import websocket
import websocket_hub
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(db) = postgres.init_db()
  let assert Ok(table) = cache.init_cache(option.Some(db))
  let ws_hub = websocket_hub.start()
  let live_user_counter = live_users.start()

  let context = context.Context(table, db, ws_hub, live_user_counter)

  stats_sampler.start(context)
  stats_scheduler.start(context)

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
