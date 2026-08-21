import gleam/option.{None}
import lustre
import lustre/effect
import sysstats

import app/state
import app/update
import app/view

pub fn main() -> Nil {
  let app = lustre.application(init, update.update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

fn init(_flags) {
  #(
    state.Model(
      page: state.Home,
      stats: sysstats.SystemStats(
        cpu_load: 0.0,
        ram_load: 0.0,
        ram_used_bytes: 0,
        ram_total_bytes: 0,
      ),
      cpu_history: [],
      ram_history: [],
      server_status: state.Checking,
      terminal_lines: [],
      probe_info_open: False,
      github_stars: None,
      live_users: 0,
      returning_visitor: None,
      welcome_open: False,
      connection_timed_out: False,
      socket: None,
      primary_connection_id: 0,
      connections: [],
      next_connection_id: 0,
    ),
    effect.batch([update.connect_websocket(0), update.load_github_stars()]),
  )
}
