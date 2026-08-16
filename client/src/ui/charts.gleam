import gleam/list
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{div, img, p}

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

pub fn checking_view() -> Element(msg) {
  div(
    [
      attribute.class(
        "flex w-full flex-col items-center justify-center gap-4 px-6 py-10 text-center",
      ),
      attribute.attribute("role", "status"),
      attribute.attribute("aria-live", "polite"),
      attribute.attribute("aria-atomic", "true"),
    ],
    [
      checking_illustration(),
      div([], [
        p([attribute.class("text-xl font-black tracking-tight")], [
          text("Connecting to server…"),
        ]),
        p(
          [
            attribute.class(
              "mx-auto mt-1 max-w-md font-mono text-xs leading-relaxed opacity-65",
            ),
          ],
          [text("Waiting for the first system stats response.")],
        ),
      ]),
    ],
  )
}

fn checking_illustration() -> Element(msg) {
  img([
    attribute.src("/server-checking.png"),
    attribute.alt(""),
    attribute.class("h-40 w-full max-w-xs object-contain"),
    attribute.attribute("width", "320"),
    attribute.attribute("height", "180"),
    attribute.attribute("aria-hidden", "true"),
  ])
}

pub fn unreachable_view(detail: String) -> Element(msg) {
  div(
    [
      attribute.class(
        "flex w-full flex-col items-center justify-center gap-4 px-6 py-10 text-center",
      ),
      attribute.attribute("role", "status"),
      attribute.attribute("aria-live", "polite"),
      attribute.attribute("aria-atomic", "true"),
    ],
    [
      unavailable_illustration(),
      div([], [
        p([attribute.class("text-xl font-black tracking-tight")], [
          text("Server unreachable"),
        ]),
        p(
          [
            attribute.class(
              "mx-auto mt-1 max-w-md font-mono text-xs leading-relaxed opacity-65",
            ),
          ],
          [text(detail <> " — chart updates will resume automatically.")],
        ),
      ]),
    ],
  )
}

fn unavailable_illustration() -> Element(msg) {
  img([
    attribute.src("/server-unreachable.png"),
    attribute.alt(""),
    attribute.class("h-40 w-full max-w-xs object-contain"),
    attribute.attribute("width", "320"),
    attribute.attribute("height", "180"),
    attribute.attribute("aria-hidden", "true"),
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
  // The live sample has no cache timestamp yet, so it becomes the final “now” point.
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
