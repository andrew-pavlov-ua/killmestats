import error.{
  type ApiError, DecodeError, FetchError, InvalidUrl, UnexpectedStatus,
}
import gleam/bool
import gleam/dynamic/decode.{type Decoder}
import gleam/fetch
import gleam/http.{Get}
import gleam/http/request.{type Request}
import gleam/javascript/promise.{type Promise}
import gleam/result
import shared.{type SystemStats, SystemStats}

pub fn get(path: String, decoder: Decoder(a)) -> Promise(Result(a, ApiError)) {
  use req <- with_json_request(path)

  req
  |> request.set_method(Get)
  |> execute(expect: 200, decoder:)
}

fn with_json_request(
  path: String,
  callback: fn(Request(String)) -> Promise(Result(a, ApiError)),
) -> Promise(Result(a, ApiError)) {
  let url = api_base_url() <> path

  request.to(url)
  |> result.replace_error(InvalidUrl(url))
  |> result.map(request.set_header(_, "accept", "application/json"))
  |> promise.resolve
  |> promise.try_await(callback)
}

fn execute(
  req: Request(String),
  expect expect: Int,
  decoder decoder: Decoder(a),
) -> Promise(Result(a, ApiError)) {
  req
  |> fetch.send
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(result.map_error(_, FetchError))
  |> promise.map_try(fn(response) {
    use <- bool.guard(
      response.status != expect,
      Error(UnexpectedStatus(response.status)),
    )

    response.body
    |> decode.run(decoder)
    |> result.map_error(DecodeError)
  })
}

fn api_base_url() -> String {
  "http://localhost:8000"
}

pub fn fetch_stats() -> Promise(Result(SystemStats, ApiError)) {
  get("/api/stats", stats_decoder())
}

// complicated json object
// fn stats_decoder() -> Decoder(SystemStats) {
//   use stats <- decode.field("systemStats", system_stats_decoder())
//   decode.success(stats)
// }

fn stats_decoder() -> Decoder(SystemStats) {
  use cpu_load <- decode.field("cpu_load", decode.float)
  use ram_load <- decode.field("ram_load", decode.float)
  decode.success(SystemStats(cpu_load:, ram_load:))
}
