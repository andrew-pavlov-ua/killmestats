import gleam/io
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import page/home
import shared

import gleam/javascript/promise

import api
import error

pub type Page {
  Home
  // Status
}

type Model {
  Model(page: Page, stats: shared.SystemStats)
}

type Msg {
  UserClickedSubmit
  StatsReceived(Result(shared.SystemStats, error.ApiError))
}

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

fn init(_flags) {
  #(
    Model(page: Home, stats: shared.SystemStats(cpu_load: 0.0, ram_load: 0.0)),
    show_stats(),
  )
}

fn view(model: Model) -> Element(Msg) {
  case model.page {
    Home -> home.view(model.stats, UserClickedSubmit)
  }
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserClickedSubmit -> #(model, show_stats())
    StatsReceived(Ok(stats)) -> #(Model(..model, stats: stats), effect.none())

    StatsReceived(Error(err)) -> {
      io.print_error(error.message(err))
      #(model, effect.none())
    }
  }
}

fn show_stats() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    api.fetch_stats()
    |> promise.map(fn(result) { dispatch(StatsReceived(result)) })

    Nil
  })
}
// fn static_files() -> List(fs.File) {
//   [
//     fs.Copy("fonts"),
//     fs.Copy("images"),
//     fs.Copy("img"),
//     fs.Copy("javascript"),
//     fs.Copy("styles"),
//     fs.Copy("funding.json"),
//   ]
// }
