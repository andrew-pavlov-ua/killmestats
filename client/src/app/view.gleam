import layout/app_shell
import lustre/element.{type Element}
import page/home
import ui/app_header

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

  app_shell.view(app_header.view(model.server_status), page)
}
