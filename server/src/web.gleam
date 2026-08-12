import cors_builder as cors
import gleam/http
import wisp

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  use req <- cors.wisp_middleware(req, cors_config())

  handle_request(req)
}

fn cors_config() {
  cors.new()
  |> cors.allow_origin("http://localhost:1234")
  |> cors.allow_origin("http://localhost:8080")
  |> cors.allow_method(http.Get)
  |> cors.allow_method(http.Post)
}
