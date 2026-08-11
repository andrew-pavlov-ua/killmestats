import gleam/float
import gleam/int
import lustre/element.{text}
import lustre/element/html.{button, div, p}
import lustre/event
import shared.{type SystemStats}

pub fn view(stats: SystemStats, fetch_clicked: msg) {
  let rounded_cpu_load =
    stats.cpu_load
    |> float.round
    |> int.to_string

  let rounded_ram_load =
    stats.ram_load
    |> float.round
    |> int.to_string

  div([], [
    p([], [text("Server CPU loading: " <> rounded_cpu_load <> "%")]),
    p([], [text("Server RAM loading: " <> rounded_ram_load <> "%")]),
    button([event.on_click(fetch_clicked)], [text("GET SERVER STATS")]),
  ])
}
