import context
import gleam/erlang/process
import websocket_hub

const stats_interval_ms = 1000

pub fn start(context: context.Context) -> Nil {
  process.spawn(fn() { schedule_next_broadcast(context) })

  Nil
}

fn schedule_next_broadcast(context: context.Context) {
  websocket_hub.broadcast(context.ws_hub)

  process.sleep(stats_interval_ms)
  schedule_next_broadcast(context)
}
