import gleam/json
import wisp.{type Response}

pub fn get_calculation() -> Response {
  let body =
    json.object([
      #("result", json.string("GET request response")),
    ])
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(body)
}

pub fn save_calculation() -> Response {
  let body =
    json.object([
      #("result", json.string("POST request response")),
    ])
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(body)
}
