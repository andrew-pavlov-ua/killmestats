import gleam/http.{Get, Post}
import log
import system_stats/stats
import web
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    ["api", ..rest] -> handle_api(rest, req)
    _ -> wisp.not_found()
  }
}

fn handle_api(segments: List(String), req: Request) -> Response {
  case segments, req.method {
    // [], Get -> ping.get_calculation()
    // [], Post -> ping.save_calculation()
    [], _ -> wisp.method_not_allowed([Get, Post])

    // Keep an HTTP fallback for diagnostics and non-WebSocket clients
    ["stats"], Get -> stats.get_stats()
    ["panic"], Post -> panic_program()
    // ["time-stats"], Get -> ping.get_calculation()

    _, _ -> wisp.not_found()
  }
}

fn panic_program() {
  log.info("Triggering intentional panic")
  panic
}
