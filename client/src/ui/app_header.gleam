import app/state.{type ServerStatus}
import lustre/attribute
import lustre/element.{type Element, text}
import lustre/element/html.{div, header, span}

pub fn view(status: ServerStatus) -> Element(msg) {
  header(
    [
      attribute.class(
        "border-gleam-ink/15 mx-auto flex max-w-6xl items-center justify-between border-b px-6 py-6 lg:px-10",
      ),
    ],
    [
      div([attribute.class("flex items-center gap-3")], [
        span(
          [
            attribute.class(
              "bg-gleam-pink border-gleam-ink grid size-10 rotate-3 place-items-center rounded-xl border-2 text-xl font-black",
            ),
            attribute.attribute("aria-hidden", "true"),
          ],
          [text("G")],
        ),
        span([attribute.class("text-lg font-black tracking-tight")], [
          text("killmestats"),
        ]),
      ]),
      status_indicator(status),
    ],
  )
}

fn status_indicator(status: ServerStatus) -> Element(msg) {
  div(
    [
      attribute.class(status_badge_class(status)),
      attribute.attribute("role", "status"),
      attribute.attribute("aria-live", "polite"),
    ],
    [
      span([attribute.class(status_dot_class(status))], []),
      text(status_label(status)),
    ],
  )
}

fn status_badge_class(status: ServerStatus) -> String {
  case status {
    state.Alive ->
      "border-gleam-ink/20 bg-white/50 flex items-center gap-2 rounded-full border px-3 py-1.5 font-mono text-xs font-bold uppercase tracking-widest"
    state.Checking ->
      "border-gleam-ink bg-gleam-yellow flex items-center gap-2 rounded-full border px-3 py-1.5 font-mono text-xs font-bold uppercase tracking-widest"
    state.ServerUnreachable(_) ->
      "border-gleam-ink bg-red-100 flex items-center gap-2 rounded-full border px-3 py-1.5 font-mono text-xs font-bold uppercase tracking-widest"
  }
}

fn status_dot_class(status: ServerStatus) -> String {
  case status {
    state.Alive ->
      "bg-gleam-cyan border-gleam-ink size-2.5 rounded-full border"
    state.Checking ->
      "bg-gleam-yellow border-gleam-ink size-2.5 rounded-full border"
    state.ServerUnreachable(_) ->
      "bg-red-500 border-gleam-ink size-2.5 rounded-full border"
  }
}

fn status_label(status: ServerStatus) -> String {
  case status {
    state.Checking -> "checking"
    state.Alive -> "still alive"
    state.ServerUnreachable(_) -> "unreachable"
  }
}
