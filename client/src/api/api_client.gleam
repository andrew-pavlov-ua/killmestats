import api/error.{type ApiError, FetchError, InvalidUrl}
import config
import gleam/fetch
import gleam/http.{Post}
import gleam/http/request.{type Request}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub fn post(path: String) -> Promise(Result(Nil, ApiError)) {
  use req <- with_json_request(path)

  req
  |> request.set_method(Post)
  |> fetch.send
  |> promise.map(result.map_error(_, FetchError))
  |> promise.map(result.map(_, fn(_) { Nil }))
}

fn with_json_request(
  path: String,
  callback: fn(Request(String)) -> Promise(Result(a, ApiError)),
) -> Promise(Result(a, ApiError)) {
  // Keeping URL construction here gives every request the same runtime host rules.
  let url = config.api_base_url() <> path

  request.to(url)
  |> result.replace_error(InvalidUrl(url))
  |> result.map(request.set_header(_, "accept", "application/json"))
  |> promise.resolve
  |> promise.try_await(callback)
}
