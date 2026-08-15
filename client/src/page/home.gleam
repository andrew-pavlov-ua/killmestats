import app/state.{type ServerStatus}
import format/bytes
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import lustre/attribute
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, input, main, p, span}
import lustre/event
import sysstats.{type SystemStats}

pub fn view(
  stats: SystemStats,
  status: ServerStatus,
  terminal_lines: List(String),
  connection_count: Int,
  connected_count: Int,
  max_connections: Int,
  remove_connection: msg,
  add_connection: msg,
  set_connection_count: fn(String) -> msg,
  panic_clicked: msg,
) {
  let #(rounded_cpu_load, ram_usage) = case status {
    state.Alive -> #(
      stats.cpu_load
        |> float.round
        |> int.to_string,
      // bytes.compact_gibibytes(stats.ram_used_bytes, False)
      bytes.human_readable(stats.ram_used_bytes, False)
        <> "/"
        <> bytes.compact_gibibytes(stats.ram_total_bytes, True)
        // <> bytes.human_readable(stats.ram_total_bytes, True)
        <> " GB",
    )

    _ -> #("--", "--")
  }

  main(
    [
      attribute.class(
        "mx-auto grid max-w-6xl gap-12 px-6 py-16 lg:grid-cols-[1.05fr_0.95fr] lg:items-center lg:px-10 lg:py-24",
      ),
    ],
    [
      div([], [
        p(
          [
            attribute.class(
              "mb-5 font-mono text-sm font-bold uppercase tracking-[0.2em]",
            ),
          ],
          [text("/// let it crash. watch it recover.")],
        ),
        h1(
          [
            attribute.class(
              "max-w-xl text-5xl font-black leading-[0.98] tracking-[-0.055em] sm:text-6xl lg:text-7xl",
            ),
          ],
          [
            text("Kill it. "),
            span(
              [
                attribute.class(
                  "decoration-gleam-pink decoration-8 underline underline-offset-4",
                ),
              ],
              [text("It comes back.")],
            ),
          ],
        ),
        p(
          [
            attribute.class(
              "mt-7 max-w-lg text-lg font-medium leading-relaxed opacity-75",
            ),
          ],
          [
            text(
              "A live resilience experiment for exploring the fault-tolerant possibilities of Gleam, Erlang, and OTP.",
            ),
          ],
        ),
        button(
          [
            attribute.class(
              "bg-gleam-yellow border-gleam-ink shadow-gleam mt-9 rounded-xl border-2 px-6 py-3.5 font-mono text-sm font-black uppercase tracking-wider transition-transform hover:-translate-y-0.5 active:translate-x-1 active:translate-y-1 active:shadow-none",
            ),
            event.on_click(panic_clicked),
          ],
          [text("Probe the system →")],
        ),
      ]),
      div(
        [
          attribute.class(
            "border-gleam-ink shadow-gleam relative rounded-card border-2 bg-white p-5 sm:p-7",
          ),
        ],
        [
          div(
            [
              attribute.class(
                "border-gleam-ink/20 mb-6 flex items-center justify-between border-b pb-4",
              ),
            ],
            [
              p([attribute.class("font-mono text-sm font-bold")], [
                text("killmestats.gleam"),
              ]),
              div([attribute.class("flex gap-2")], [
                span(
                  [
                    attribute.class(
                      "bg-gleam-pink border-gleam-ink size-3 rounded-full border",
                    ),
                  ],
                  [],
                ),
                span(
                  [
                    attribute.class(
                      "bg-gleam-yellow border-gleam-ink size-3 rounded-full border",
                    ),
                  ],
                  [],
                ),
                span(
                  [
                    attribute.class(
                      "bg-gleam-cyan border-gleam-ink size-3 rounded-full border",
                    ),
                  ],
                  [],
                ),
              ]),
            ],
          ),
          div([attribute.class("grid gap-4 sm:grid-cols-2")], [
            stat_card(
              "CPU load",
              rounded_cpu_load,
              "%",
              "text-4xl",
              "bg-gleam-pink",
            ),
            stat_card(
              "RAM usage",
              ram_usage,
              "",
              "whitespace-nowrap text-[1.75rem]",
              "bg-gleam-cyan",
            ),
          ]),
          p(
            [
              attribute.class(
                "mt-6 font-mono text-xs font-semibold leading-relaxed opacity-60",
              ),
            ],
            [text(status_detail(status))],
          ),
          connection_controls(
            connection_count,
            connected_count,
            max_connections,
            remove_connection,
            add_connection,
            set_connection_count,
          ),
          terminal(terminal_lines),
        ],
      ),
    ],
  )
}

fn connection_controls(
  count: Int,
  connected_count: Int,
  max_connections: Int,
  remove_connection: msg,
  add_connection: msg,
  set_connection_count: fn(String) -> msg,
) {
  div(
    [
      attribute.class(
        "border-gleam-ink/20 mt-6 flex items-center justify-between rounded-xl border bg-gleam-cream/40 p-2",
      ),
    ],
    [
      button(
        [
          attribute.class(
            "border-gleam-ink grid size-9 place-items-center rounded-lg border-2 bg-white font-mono text-xl font-black disabled:cursor-not-allowed disabled:opacity-30",
          ),
          attribute.disabled(count <= 1),
          attribute.attribute("aria-label", "Remove WebSocket connection"),
          event.on_click(remove_connection),
        ],
        [text("−")],
      ),
      div([attribute.class("text-center font-mono")], [
        input([
          attribute.class(
            "w-16 rounded-md bg-transparent text-center text-lg font-black tabular-nums [appearance:textfield] focus-visible:ring-2 focus-visible:ring-gleam-ink focus-visible:ring-offset-2 [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none",
          ),
          attribute.type_("number"),
          attribute.inputmode("numeric"),
          attribute.name("connection-count"),
          attribute.autocomplete("off"),
          attribute.min("1"),
          attribute.max(int.to_string(max_connections)),
          attribute.value(int.to_string(count)),
          attribute.attribute("aria-label", "WebSocket connection count"),
          event.on_change(set_connection_count),
        ]),
        p(
          [
            attribute.class(
              "text-[0.65rem] font-bold uppercase tracking-widest opacity-60",
            ),
          ],
          [text("connections")],
        ),
        p(
          [
            attribute.class(
              "border-gleam-ink/20 mt-1.5 inline-flex items-center gap-1.5 rounded-full border bg-white px-2 py-0.5 text-[0.65rem] font-bold tracking-wide text-gleam-ink shadow-sm tabular-nums",
            ),
            attribute.attribute("role", "status"),
            attribute.attribute("aria-live", "polite"),
            attribute.attribute("aria-atomic", "true"),
          ],
          [
            span(
              [
                attribute.class(
                  "size-1.5 rounded-full bg-gleam-cyan ring-1 ring-gleam-ink/30",
                ),
                attribute.attribute("aria-hidden", "true"),
              ],
              [],
            ),
            text(int.to_string(connected_count) <> " connected"),
          ],
        ),
      ]),
      button(
        [
          attribute.class(
            "border-gleam-ink bg-gleam-cyan grid size-9 place-items-center rounded-lg border-2 font-mono text-xl font-black disabled:cursor-not-allowed disabled:opacity-30",
          ),
          attribute.disabled(count >= max_connections),
          attribute.attribute("aria-label", "Add WebSocket connection"),
          event.on_click(add_connection),
        ],
        [text("+")],
      ),
    ],
  )
}

fn terminal(lines: List(String)) {
  let output = case lines {
    [] -> [
      p([attribute.class("opacity-50")], [text("$ waiting for input...")]),
    ]
    lines -> list.map(lines, terminal_line)
  }

  div(
    [
      attribute.class(
        "border-gleam-ink mt-6 overflow-hidden rounded-xl border-2 bg-gleam-ink text-white",
      ),
    ],
    [
      div(
        [
          attribute.class(
            "border-white/20 flex items-center justify-between border-b px-4 py-2",
          ),
        ],
        [
          p([attribute.class("font-mono text-xs font-bold")], [
            text("server terminal"),
          ]),
          span([attribute.class("size-2 rounded-full bg-gleam-cyan")], []),
        ],
      ),
      div(
        [
          attribute.class(
            "h-28 overflow-y-auto px-4 py-3 font-mono text-xs leading-5",
          ),
          attribute.attribute("aria-live", "polite"),
        ],
        output,
      ),
    ],
  )
}

fn terminal_line(line: String) -> Element(msg) {
  let rest = string.remove_prefix(line, "EROR ")

  p([attribute.class("break-words")], [
    span([attribute.class("font-black text-gleam-pink")], [text("EROR ")]),
    text(rest),
  ])
}

fn status_detail(status: ServerStatus) -> String {
  case status {
    state.Checking -> "status: Checking // waiting for the first response"
    state.Alive -> "status: Alive // supervisor standing by"
    state.ServerUnreachable(detail) ->
      "status: Unreachable // " <> detail <> " // reconnecting"
  }
}

fn stat_card(
  label: String,
  value: String,
  suffix: String,
  value_class: String,
  accent: String,
) {
  div(
    [
      attribute.class(
        "border-gleam-ink relative overflow-hidden rounded-2xl border-2 p-5",
      ),
    ],
    [
      span(
        [
          attribute.class(
            accent
            <> " border-gleam-ink absolute -right-5 -top-5 size-20 rounded-full border-2",
          ),
          attribute.attribute("aria-hidden", "true"),
        ],
        [],
      ),
      p(
        [
          attribute.class(
            "relative font-mono text-xs font-bold uppercase tracking-widest opacity-60",
          ),
        ],
        [text(label)],
      ),
      p(
        [
          attribute.class(
            "relative mt-8 font-black tracking-[-0.06em] " <> value_class,
          ),
        ],
        [text(value), span([attribute.class("ml-1")], [text(suffix)])],
      ),
    ],
  )
}
