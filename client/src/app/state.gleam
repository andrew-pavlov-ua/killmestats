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
    // History includes the latest live sample appended to the cached samples.
    cpu_history: List(Float),
    ram_history: List(Float),
    server_status: ServerStatus,
    terminal_lines: List(String),
    live_users: Int,
    connection_timed_out: Bool,
    socket: Option(websocket.WebSocket),
    primary_connection_id: Int,
    connections: List(Connection),
    next_connection_id: Int,
  )
}

pub type Connection {
  Connecting(id: Int)
  Connected(id: Int, socket: websocket.WebSocket)
}

pub type Msg {
  Tick(Int)
  ConnectionTimedOut(Int)
  UserClickedPanic
  AddConnection
  RemoveConnection
  SetConnectionCount(String)
  SocketEvent(Int, websocket.WebSocketEvent)
  ExtraSocketEvent(Int, websocket.WebSocketEvent)
}

pub type ServerStatus {
  Checking
  Alive
  ServerUnreachable(detail: String)
}
