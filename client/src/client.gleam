import gleam/io
import layout/app_shell
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import page/home
import sysstats
import ui/app_header

import gleam/javascript/promise

import api/api_client
import api/error
import api/system_stats
import ffi/timer

const poll_interval_ms = 1000

const panic_log = "EROR function=\"panic_program\" message=\"`panic` expression evaluated.\" module=\"router\" file=\"src/router.gleam\" gleam_error=Panic class=Errored"

pub type Page {
  Home
}

type Model {
  Model(
    page: Page,
    stats: sysstats.SystemStats,
    server_status: system_stats.ServerStatus,
    terminal_lines: List(String),
  )
}

type Msg {
  Tick
  UserClickedPanic
  StatsReceived(Result(sysstats.SystemStats, error.ApiError))
}

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

fn init(_flags) {
  #(
    Model(
      page: Home,
      stats: sysstats.SystemStats(cpu_load: 0.0, ram_load: 0.0),
      server_status: system_stats.Checking,
      terminal_lines: [],
    ),
    fetch_stats(),
  )
}

fn view(model: Model) -> Element(Msg) {
  let page = case model.page {
    Home ->
      home.view(
        model.stats,
        model.server_status,
        model.terminal_lines,
        UserClickedPanic,
      )
  }

  app_shell.view(app_header.view(model.server_status), page)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Tick -> #(model, fetch_stats())
    UserClickedPanic -> #(
      Model(..model, terminal_lines: [panic_log, ..model.terminal_lines]),
      panic_server(),
    )
    StatsReceived(Ok(stats)) -> #(
      Model(..model, stats: stats, server_status: system_stats.Alive),
      schedule_next_fetch(),
    )

    StatsReceived(Error(err)) -> {
      io.print_error(error.message(err))

      #(
        Model(..model, server_status: system_stats.server_status(err)),
        schedule_next_fetch(),
      )
    }
  }
}

fn schedule_next_fetch() -> Effect(Msg) {
  timer.after(poll_interval_ms, Tick)
}

fn panic_server() -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    api_client.post("/api/panic")
    Nil
  })
}

fn fetch_stats() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    system_stats.fetch()
    |> promise.map(fn(result) { dispatch(StatsReceived(result)) })

    Nil
  })
}
