import dream_ets/table
import gleam/time/timestamp
import live_users
import pog
import sysstats
import websocket_hub

pub type Context {
  Context(
    cache: table.Table(timestamp.Timestamp, sysstats.SystemStats),
    db: pog.Connection,
    ws_hub: websocket_hub.Hub,
    live_users_counter: live_users.Counter,
  )
}
