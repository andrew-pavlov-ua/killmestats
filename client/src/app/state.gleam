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
    server_status: ServerStatus,
    terminal_lines: List(String),
    connection_timed_out: Bool,
    // The main websocket which transports data
    socket: Option(websocket.WebSocket),
    // Identifies the current primary connection attempt so stale events are ignored.
    primary_connection_id: Int,
    // List of WebSockets
    connections: List(Connection),
    // The next ws id to omit id's confusion
    next_connection_id: Int,
  )
}

pub type Connection {
  Connecting(id: Int)
  Connected(id: Int, socket: websocket.WebSocket)
}

pub type Msg {
  Tick(Int)
  ExtraTick(Int)
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
