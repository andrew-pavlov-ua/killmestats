import app/state.{type ServerStatus}
import gleam/int
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element, text}
import lustre/element/html.{a, div, header, img, span}

const repository_url = "https://github.com/andrew-pavlov-ua/killmestats"

pub fn view(status: ServerStatus, stars: Option(Int)) -> Element(msg) {
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
        span(
          [
            attribute.class(
              "hidden text-lg font-black tracking-tight sm:inline",
            ),
          ],
          [text("killmestats")],
        ),
      ]),
      div([attribute.class("flex items-center gap-2 sm:gap-3")], [
        github_badge(stars),
        status_indicator(status),
      ]),
    ],
  )
}

fn github_badge(stars: Option(Int)) -> Element(msg) {
  let #(count, label) = case stars {
    Some(count) -> #(
      int.to_string(count),
      "View killmestats on GitHub, "
        <> int.to_string(count)
        <> case count == 1 {
        True -> " star"
        False -> " stars"
      },
    )
    None -> #("Star", "Star killmestats on GitHub")
  }

  a(
    [
      attribute.href(repository_url),
      attribute.class(
        "border-gleam-ink shadow-[2px_2px_0_rgb(47_41_51)] inline-flex min-h-10 items-stretch overflow-hidden rounded-lg border-2 bg-white font-mono text-xs font-black transition-[transform,box-shadow,background-color] hover:-translate-y-0.5 hover:bg-gleam-pink/20 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gleam-ink focus-visible:ring-offset-2 active:translate-x-0.5 active:translate-y-0.5 active:shadow-none",
      ),
      attribute.aria_label(label),
      attribute.attribute("translate", "no"),
    ],
    [
      span([attribute.class("flex items-center gap-2 px-2.5 sm:px-3")], [
        img([
          attribute.src("/github-invertocat.png"),
          attribute.alt(""),
          attribute.class("size-4 shrink-0 object-contain"),
          attribute.attribute("width", "16"),
          attribute.attribute("height", "16"),
          attribute.aria_hidden(True),
        ]),
        span([attribute.class("hidden sm:inline")], [text("GitHub")]),
      ]),
      span(
        [
          attribute.class(
            "border-gleam-ink flex min-w-10 items-center justify-center gap-1 border-l-2 bg-gleam-yellow px-2 tabular-nums",
          ),
          attribute.aria_live("polite"),
          attribute.aria_atomic(True),
        ],
        [
          span(
            [
              attribute.class("text-lg leading-none"),
              attribute.aria_hidden(True),
            ],
            [text("★")],
          ),
          text(count),
        ],
      ),
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
      span(
        [
          attribute.class(status_dot_class(status)),
          attribute.attribute("aria-hidden", "true"),
        ],
        [],
      ),
      text(status_label(status)),
    ],
  )
}

fn status_badge_class(status: ServerStatus) -> String {
  case status {
    state.Alive ->
      "border-gleam-ink shadow-[2px_2px_0_rgb(47_41_51)] inline-flex min-h-10 items-center gap-2 rounded-lg border-2 bg-white px-3 font-mono text-xs font-black uppercase tracking-widest"
    state.Checking ->
      "border-gleam-ink shadow-[2px_2px_0_rgb(47_41_51)] inline-flex min-h-10 items-center gap-2 rounded-lg border-2 bg-gleam-yellow px-3 font-mono text-xs font-black uppercase tracking-widest"
    state.ServerUnreachable(_) ->
      "border-gleam-ink shadow-[2px_2px_0_rgb(47_41_51)] inline-flex min-h-10 items-center gap-2 rounded-lg border-2 bg-red-100 px-3 font-mono text-xs font-black uppercase tracking-widest"
  }
}

fn status_dot_class(status: ServerStatus) -> String {
  case status {
    state.Alive -> "bg-gleam-cyan border-gleam-ink size-2.5 rounded-full border"
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
