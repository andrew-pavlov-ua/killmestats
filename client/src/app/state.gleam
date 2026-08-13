import api/system_stats
import gleam/option.{type Option}
import lustre_websocket as websocket
import sysstats

pub type Page {
  Home
}

pub type Model {
  Model(
    page: Page,
    stats: sysstats.SystemStats,
    server_status: system_stats.ServerStatus,
    terminal_lines: List(String),
    socket: Option(websocket.WebSocket),
    connection_timed_out: Bool,
  )
}

pub type Msg {
  Tick
  ConnectionTimedOut
  UserClickedPanic
  SocketEvent(websocket.WebSocketEvent)
}
