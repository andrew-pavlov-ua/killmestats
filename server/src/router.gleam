import gleam/http.{Get, Post}
import log
import ping/ping
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
    [], Get -> ping.get_calculation()
    [], Post -> ping.save_calculation()
    [], _ -> wisp.method_not_allowed([Get, Post])

    ["stats"], Get -> stats.get_stats()
    ["panic"], Post -> panic_program()

    _, _ -> wisp.not_found()
  }
}

fn panic_program() {
  log.info("Triggering intentional panic")
  panic
}
