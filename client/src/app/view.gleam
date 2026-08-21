import config
import gleam/list
import lustre/element.{type Element, text}
import page/home
import ui/app_header

import lustre/attribute
import lustre/element/html.{a, div}

import app/state

pub fn view(model: state.Model) -> Element(state.Msg) {
  let connected_count =
    list.count(model.connections, fn(connection) {
      case connection {
        state.Connected(_, _) -> True
        state.Connecting(_) -> False
      }
    })

  let page = case model.page {
    state.Home ->
      home.view(
        model.stats,
        model.cpu_history,
        model.ram_history,
        model.server_status,
        model.terminal_lines,
        model.live_users,
        list.length(model.connections),
        connected_count,
        config.max_socket_connections(),
        state.RemoveConnection,
        state.AddConnection,
        state.SetConnectionCount,
        state.UserClickedPanic,
      )
  }

  div([attribute.class("min-h-screen overflow-x-clip")], [
    a(
      [
        attribute.href("#main-content"),
        attribute.class(
          "bg-gleam-yellow border-gleam-ink fixed left-4 top-4 z-50 -translate-y-24 rounded-lg border-2 px-4 py-2 font-mono font-bold shadow-gleam transition-transform focus-visible:translate-y-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gleam-ink focus-visible:ring-offset-2",
        ),
      ],
      [text("Skip to Main Content")],
    ),
    app_header.view(model.server_status),
    page,
  ])
}
