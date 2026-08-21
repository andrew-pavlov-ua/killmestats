import lustre/attribute
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h2, p, span}
import lustre/event

pub fn view(dismiss: msg, key_pressed: fn(String) -> msg) -> Element(msg) {
  div(
    [
      attribute.class(
        "bg-gleam-purple/55 fixed inset-0 z-[200] grid place-items-center overflow-y-auto overscroll-contain p-4 backdrop-blur-sm sm:p-6",
      ),
    ],
    [
      div(
        [
          attribute.class(
            "border-gleam-ink shadow-gleam w-full max-w-lg overflow-hidden rounded-2xl border-2 bg-gleam-cream",
          ),
          attribute.attribute("role", "dialog"),
          attribute.aria_modal(True),
          attribute.aria_labelledby("welcome-dialog-title"),
          attribute.attribute("aria-describedby", "welcome-dialog-description"),
          event.on_keydown(key_pressed),
        ],
        [
          div(
            [
              attribute.class(
                "border-gleam-ink flex items-center justify-between border-b-2 bg-white px-5 py-4 sm:px-6",
              ),
            ],
            [
              div(
                [
                  attribute.class("flex items-center gap-3"),
                  attribute.attribute("translate", "no"),
                ],
                [
                  span(
                    [
                      attribute.class(
                        "bg-gleam-pink border-gleam-ink grid size-9 rotate-3 place-items-center rounded-lg border-2 text-lg font-black",
                      ),
                      attribute.aria_hidden(True),
                    ],
                    [text("G")],
                  ),
                  span([attribute.class("font-black tracking-tight")], [
                    text("killmestats"),
                  ]),
                ],
              ),
              div(
                [
                  attribute.class(
                    "border-gleam-ink inline-flex items-center gap-2 rounded-full border bg-gleam-cyan/60 px-3 py-1 font-mono text-[0.6875rem] font-black uppercase tracking-widest",
                  ),
                ],
                [
                  span(
                    [
                      attribute.class(
                        "border-gleam-ink size-2 rounded-full border bg-gleam-cyan",
                      ),
                      attribute.aria_hidden(True),
                    ],
                    [],
                  ),
                  text("Live"),
                ],
              ),
            ],
          ),
          div([attribute.class("p-6 sm:p-8")], [
            h2(
              [
                attribute.id("welcome-dialog-title"),
                attribute.class(
                  "text-balance text-4xl font-black leading-none tracking-[-0.05em] sm:text-5xl",
                ),
              ],
              [text("Welcome to killmestats.")],
            ),
            p(
              [
                attribute.id("welcome-dialog-description"),
                attribute.class(
                  "mt-5 text-pretty text-base font-medium leading-relaxed opacity-75 sm:text-lg",
                ),
              ],
              [
                text(
                  "This dashboard shows live CPU and memory usage. Open extra connections or crash the server to watch it recover.",
                ),
              ],
            ),
            div(
              [
                attribute.class(
                  "mt-6 flex flex-wrap gap-2 font-mono text-xs font-bold",
                ),
                attribute.aria_hidden(True),
              ],
              [
                span(
                  [
                    attribute.class(
                      "border-gleam-ink rounded-lg border bg-gleam-pink/45 px-3 py-1.5",
                    ),
                  ],
                  [text("CPU")],
                ),
                span(
                  [
                    attribute.class(
                      "border-gleam-ink rounded-lg border bg-gleam-yellow/60 px-3 py-1.5",
                    ),
                  ],
                  [text("MEMORY")],
                ),
                span(
                  [
                    attribute.class(
                      "border-gleam-ink rounded-lg border bg-gleam-cyan/60 px-3 py-1.5",
                    ),
                  ],
                  [text("CONNECTIONS")],
                ),
              ],
            ),
            button(
              [
                attribute.class(
                  "bg-gleam-yellow border-gleam-ink shadow-[3px_3px_0_rgb(47_41_51)] mt-7 min-h-12 w-full rounded-xl border-2 px-5 py-3 font-mono text-sm font-black uppercase tracking-wider transition-[transform,box-shadow,background-color] hover:-translate-y-0.5 hover:bg-gleam-pink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-gleam-ink focus-visible:ring-offset-4 active:translate-x-0.5 active:translate-y-0.5 active:shadow-none",
                ),
                attribute.autofocus(True),
                event.on_click(dismiss),
              ],
              [text("Open Dashboard")],
            ),
          ]),
        ],
      ),
    ],
  )
}
