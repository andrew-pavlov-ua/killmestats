import gleam/list
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

const chart_id = "system-history-chart"

pub fn view() -> Element(msg) {
  html.canvas([
    attribute.id(chart_id),
    attribute.attribute("role", "img"),
    attribute.attribute(
      "aria-label",
      "Line chart showing CPU and RAM usage history as percentages",
    ),
  ])
}

pub fn render(
  cpu_history: List(Float),
  ram_history: List(Float),
  timestamps: List(Int),
) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    render_chart(chart_id, cpu_history, ram_history, timestamps)
  })
}

pub fn values(samples: List(a), select: fn(a) -> Float, latest: Float) {
  samples
  |> list.map(select)
  |> list.append([latest])
}

@external(javascript, "../ffi/charts_ffi.mjs", "renderChart")
fn render_chart(
  id: String,
  cpu_history: List(Float),
  ram_history: List(Float),
  timestamps: List(Int),
) -> Nil
