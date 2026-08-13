import lustre/element.{type Element}
import page/home
import ui/app_header

import lustre/attribute
import lustre/element/html.{div}

import app/state

pub fn view(model: state.Model) -> Element(state.Msg) {
  let page = case model.page {
    state.Home ->
      home.view(
        model.stats,
        model.server_status,
        model.terminal_lines,
        state.UserClickedPanic,
      )
  }

  div([attribute.class("min-h-screen overflow-hidden")], [
    app_header.view(model.server_status),
    page,
  ])
}
