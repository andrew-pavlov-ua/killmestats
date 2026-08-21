import context
import gleam/erlang/process
import system_stats/payload
import websocket_hub

const stats_interval_ms = 1000

pub fn start(context: context.Context) -> Nil {
  process.spawn(fn() { schedule_next_broadcast(context) })

  Nil
}

fn schedule_next_broadcast(context: context.Context) {
  websocket_hub.broadcast(context.ws_hub, payload.encode(context))

  process.sleep(stats_interval_ms)
  schedule_next_broadcast(context)
}
