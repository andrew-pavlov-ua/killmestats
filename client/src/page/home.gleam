import app/state.{type ServerStatus}
import format/bytes
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, h2, input, main, p, span}
import lustre/event
import sysstats.{type SystemStats}
import ui/charts

pub fn view(
  stats: SystemStats,
  cpu_history: List(Float),
  ram_history: List(Float),
  status: ServerStatus,
  terminal_lines: List(String),
  live_users: Int,
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
      bytes.gibibytes(stats.ram_used_bytes)
        <> "/"
        <> bytes.compact_gibibytes(stats.ram_total_bytes, True)
        <> " GB",
    )

    _ -> #("--", "--")
  }

  main(
    [
      attribute.class(
        "mx-auto grid max-w-6xl gap-12 px-6 py-16 lg:grid-cols-[1.05fr_0.95fr] lg:items-center lg:px-10 lg:py-24",
      ),
      attribute.id("main-content"),
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
              "max-w-xl text-balance text-5xl font-black leading-[0.98] tracking-[-0.055em] sm:text-6xl lg:text-7xl",
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
              "bg-gleam-yellow border-gleam-ink shadow-gleam mt-9 rounded-xl border-2 px-6 py-3.5 font-mono text-sm font-black uppercase tracking-wider transition-transform hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gleam-ink focus-visible:ring-offset-4 active:translate-x-1 active:translate-y-1 active:shadow-none",
            ),
            event.on_click(panic_clicked),
          ],
          [text("Probe the System →")],
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
              attribute.attribute("role", "status"),
              attribute.attribute("aria-live", "polite"),
            ],
            [text(status_detail(status))],
          ),
          connection_controls(
            live_users,
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
      div(
        [
          attribute.class(
            "border-gleam-ink/25 relative overflow-hidden rounded-card border bg-white p-5 shadow-[0_12px_35px_rgb(47_41_51/0.10)] sm:col-span-2 sm:p-7",
          ),
        ],
        [
          div(
            [
              attribute.class("border-gleam-ink/20 border-b pb-5"),
            ],
            [
              div(
                [
                  attribute.class(
                    "flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between",
                  ),
                ],
                [
                  div([], [
                    p(
                      [
                        attribute.class(
                          "font-mono text-xs font-bold uppercase tracking-[0.2em] opacity-60",
                        ),
                      ],
                      [text("/// telemetry")],
                    ),
                    h2(
                      [
                        attribute.id("system-history-heading"),
                        attribute.class(
                          "mt-2 text-3xl font-black tracking-[-0.04em] text-balance",
                        ),
                      ],
                      [text("System History")],
                    ),
                    p(
                      [
                        attribute.class(
                          "mt-2 max-w-2xl font-medium leading-relaxed opacity-70 text-pretty",
                        ),
                      ],
                      [
                        text(
                          "Watch CPU and memory change as the supervisor keeps the system running.",
                        ),
                      ],
                    ),
                  ]),
                  div(
                    [
                      attribute.class(
                        "border-gleam-ink/30 bg-gleam-cyan/80 inline-flex w-fit shrink-0 items-center gap-2 rounded-full border px-3 py-1.5 font-mono text-xs font-black uppercase tracking-widest shadow-sm",
                      ),
                    ],
                    [
                      span(
                        [
                          attribute.class(
                            "border-gleam-ink/40 size-2 rounded-full border bg-white",
                          ),
                          attribute.attribute("aria-hidden", "true"),
                        ],
                        [],
                      ),
                      text("Live Data"),
                    ],
                  ),
                ],
              ),
              history_summary(cpu_history, ram_history),
            ],
          ),
          div(
            [
              attribute.id("charts"),
              attribute.class(
                "border-gleam-ink/20 relative mt-6 min-h-96 overflow-hidden rounded-2xl border bg-gleam-cream/50 shadow-[0_6px_20px_rgb(47_41_51/0.08)]",
              ),
              attribute.attribute("role", "group"),
              attribute.attribute("aria-labelledby", "system-history-heading"),
            ],
            [
              div(
                [
                  attribute.class("border-gleam-ink/10 flex h-1.5 border-b"),
                  attribute.attribute("aria-hidden", "true"),
                ],
                [
                  span([attribute.class("w-1/2 bg-gleam-pink")], []),
                  span([attribute.class("w-1/2 bg-gleam-cyan")], []),
                ],
              ),
              div(
                [
                  attribute.class(
                    "relative z-10 flex min-h-96 min-w-0 items-center px-3 py-4 sm:px-6 sm:py-5",
                  ),
                ],
                [history_chart(status)],
              ),
            ],
          ),
        ],
      ),
    ],
  )
}

fn history_chart(status: ServerStatus) -> Element(msg) {
  case status {
    state.Checking -> charts.checking_view()
    state.ServerUnreachable(detail) -> charts.unreachable_view(detail)
    state.Alive -> charts.view()
  }
}

fn connection_controls(
  live_users: Int,
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
        "border-gleam-ink shadow-gleam relative mt-6 overflow-hidden rounded-2xl border-2 bg-gleam-cream",
      ),
    ],
    [
      div(
        [
          attribute.class("border-gleam-ink/20 flex h-2 border-b"),
          attribute.attribute("aria-hidden", "true"),
        ],
        [
          span([attribute.class("w-2/3 bg-gleam-cyan")], []),
          span([attribute.class("w-1/3 bg-gleam-pink")], []),
        ],
      ),
      div(
        [
          attribute.class("p-4 sm:p-5"),
        ],
        [
          div([], [
            p(
              [
                attribute.class(
                  "font-mono text-xs font-black uppercase tracking-[0.2em] opacity-60",
                ),
              ],
              [text("/// client live users")],
            ),
            div([attribute.class("mt-2 flex items-center gap-3")], [
              p(
                [
                  attribute.class(
                    "text-5xl font-black leading-none tracking-[-0.07em] tabular-nums",
                  ),
                  attribute.attribute("role", "status"),
                  attribute.attribute("aria-live", "polite"),
                  attribute.attribute("aria-atomic", "true"),
                  attribute.attribute(
                    "aria-label",
                    int.to_string(live_users) <> " client users online",
                  ),
                ],
                [text(int.to_string(live_users))],
              ),
              div([], [
                p(
                  [
                    attribute.class(
                      "flex items-center gap-2 font-mono text-xs font-black uppercase tracking-widest",
                    ),
                  ],
                  [
                    span(
                      [
                        attribute.class(
                          "bg-gleam-cyan border-gleam-ink size-2.5 rounded-full border shadow-[0_0_0_3px_rgb(166_240_252/0.35)]",
                        ),
                        attribute.attribute("aria-hidden", "true"),
                      ],
                      [],
                    ),
                    text("Online Now"),
                  ],
                ),
                p(
                  [
                    attribute.class(
                      "mt-1 font-mono text-xs font-semibold opacity-55 tabular-nums",
                    ),
                  ],
                  [text("browser clients connected")],
                ),
              ]),
            ]),
          ]),
          div(
            [
              attribute.class("border-gleam-ink/20 mt-4 border-t pt-4"),
            ],
            [
              p(
                [
                  attribute.class(
                    "font-mono text-xs font-black uppercase tracking-[0.2em] opacity-60",
                  ),
                ],
                [text("/// extra connections")],
              ),
              div(
                [
                  attribute.class(
                    "mt-2 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between",
                  ),
                ],
                [
                  div([attribute.class("flex items-center gap-3")], [
                    p(
                      [
                        attribute.class(
                          "text-5xl font-black leading-none tracking-[-0.07em] tabular-nums",
                        ),
                        attribute.attribute("role", "status"),
                        attribute.attribute("aria-live", "polite"),
                        attribute.attribute("aria-atomic", "true"),
                        attribute.attribute(
                          "aria-label",
                          int.to_string(connected_count)
                            <> " of "
                            <> int.to_string(count)
                            <> " extra connections connected",
                        ),
                      ],
                      [text(int.to_string(connected_count))],
                    ),
                    div([], [
                      p(
                        [
                          attribute.class(
                            "flex items-center gap-2 font-mono text-xs font-black uppercase tracking-widest",
                          ),
                        ],
                        [
                          span(
                            [
                              attribute.class(connection_dot_class(
                                connected_count,
                                count,
                              )),
                              attribute.attribute("aria-hidden", "true"),
                            ],
                            [],
                          ),
                          text("Connected Now"),
                        ],
                      ),
                      p(
                        [
                          attribute.class(
                            "mt-1 font-mono text-xs font-semibold opacity-55 tabular-nums",
                          ),
                        ],
                        [text("of " <> int.to_string(count) <> " requested")],
                      ),
                    ]),
                  ]),
                  div(
                    [
                      attribute.class(
                        "border-gleam-ink/20 flex items-center justify-between gap-2 rounded-xl border bg-white p-2 sm:shrink-0",
                      ),
                      attribute.attribute("role", "group"),
                      attribute.attribute(
                        "aria-label",
                        "Requested extra connections",
                      ),
                    ],
                    [
                      button(
                        [
                          attribute.class(
                            "border-gleam-ink grid size-10 place-items-center rounded-lg border-2 bg-white font-mono text-xl font-black transition-[transform,background-color] hover:bg-gleam-yellow focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gleam-ink focus-visible:ring-offset-2 active:scale-95 disabled:cursor-not-allowed disabled:opacity-30",
                          ),
                          attribute.disabled(count <= 0),
                          attribute.attribute(
                            "aria-label",
                            "Remove extra WebSocket connection",
                          ),
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
                          attribute.name("extra-connection-count"),
                          attribute.autocomplete("off"),
                          attribute.min("0"),
                          attribute.max(int.to_string(max_connections)),
                          attribute.value(int.to_string(count)),
                          attribute.attribute(
                            "aria-label",
                            "Requested extra WebSocket connections",
                          ),
                          event.on_change(set_connection_count),
                        ]),
                        p(
                          [
                            attribute.class(
                              "text-[0.65rem] font-bold uppercase tracking-widest opacity-60",
                            ),
                          ],
                          [text("requested")],
                        ),
                      ]),
                      button(
                        [
                          attribute.class(
                            "border-gleam-ink bg-gleam-cyan grid size-10 place-items-center rounded-lg border-2 font-mono text-xl font-black transition-[transform,background-color] hover:bg-gleam-yellow focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gleam-ink focus-visible:ring-offset-2 active:scale-95 disabled:cursor-not-allowed disabled:opacity-30",
                          ),
                          attribute.disabled(count >= max_connections),
                          attribute.attribute(
                            "aria-label",
                            "Add extra WebSocket connection",
                          ),
                          event.on_click(add_connection),
                        ],
                        [text("+")],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  )
}

fn connection_dot_class(connected_count: Int, requested_count: Int) -> String {
  case connected_count == requested_count {
    True ->
      "bg-gleam-cyan border-gleam-ink size-2.5 rounded-full border shadow-[0_0_0_3px_rgb(166_240_252/0.35)]"
    False ->
      "bg-gleam-yellow border-gleam-ink size-2.5 rounded-full border shadow-[0_0_0_3px_rgb(247_213_111/0.35)]"
  }
}

fn terminal(lines: List(String)) {
  let output = case lines {
    [] -> [
      p([attribute.class("opacity-50")], [text("$ waiting for input…")]),
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
          span(
            [
              attribute.class("size-2 rounded-full bg-gleam-cyan"),
              attribute.attribute("aria-hidden", "true"),
            ],
            [],
          ),
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

fn history_summary(cpu_history: List(Float), ram_history: List(Float)) {
  div(
    [
      attribute.class("mt-5 grid gap-3 font-mono text-xs sm:grid-cols-2"),
      attribute.attribute("aria-label", "System history summary"),
    ],
    [
      history_metric("CPU", cpu_history, "bg-gleam-pink"),
      history_metric("RAM", ram_history, "bg-gleam-cyan"),
    ],
  )
}

fn history_metric(label: String, values: List(Float), accent: String) {
  let #(current, average, peak) = case values {
    [] -> #("--", "--", "--")
    [first, ..rest] -> {
      let #(sum, maximum, count) =
        list.fold(rest, #(first, first, 1), fn(summary, value) {
          let #(sum, maximum, count) = summary
          #(sum +. value, float.max(maximum, value), count + 1)
        })
      let current = list.last(values) |> result.unwrap(first)
      #(percent(current), percent(sum /. int.to_float(count)), percent(maximum))
    }
  }

  div(
    [
      attribute.class(
        "border-gleam-ink/20 min-w-0 rounded-xl border bg-white/70 px-4 py-3",
      ),
    ],
    [
      div([attribute.class("mb-2 flex items-center gap-2 font-black")], [
        span(
          [
            attribute.class(accent <> " size-2 rounded-full"),
            attribute.attribute("aria-hidden", "true"),
          ],
          [],
        ),
        text(label),
      ]),
      div([attribute.class("grid grid-cols-3 gap-2 tabular-nums")], [
        summary_value("Current", current),
        summary_value("Average", average),
        summary_value("Peak", peak),
      ]),
    ],
  )
}

fn summary_value(label: String, value: String) {
  div([], [
    p([attribute.class("text-base font-black leading-none")], [text(value)]),
    p([attribute.class("mt-0.5 opacity-55")], [text(label)]),
  ])
}

fn percent(value: Float) -> String {
  value |> float.round |> int.to_string |> fn(value) { value <> "%" }
}
