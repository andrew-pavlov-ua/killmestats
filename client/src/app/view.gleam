import config
import gleam/list
import gleam/option
import lustre/element.{type Element}
import page/home
import ui/app_header

import lustre/attribute
import lustre/element/html.{div}

import app/state

pub fn view(model: state.Model) -> Element(state.Msg) {
  let connected_count =
    list.count(model.connections, fn(connection) {
      case connection {
        state.Connected(_, _) -> True
        state.Connecting(_) -> False
      }
    })
    + case model.socket {
      option.Some(_) -> 1
      option.None -> 0
    }

  let page = case model.page {
    state.Home ->
      home.view(
        model.stats,
        model.server_status,
        model.terminal_lines,
        list.length(model.connections) + 1,
        connected_count,
        config.max_socket_connections(),
        state.RemoveConnection,
        state.AddConnection,
        state.SetConnectionCount,
        state.UserClickedPanic,
      )
  }

  div([attribute.class("min-h-screen overflow-hidden")], [
    app_header.view(model.server_status),
    page,
  ])
}
