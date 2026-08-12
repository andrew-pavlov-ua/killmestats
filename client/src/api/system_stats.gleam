import api/api_client
import api/error.{type ApiError}
import gleam/fetch
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/list
import sysstats.{type SystemStats}

const request_timeout_ms = 3000

pub fn fetch() -> Promise(Result(SystemStats, ApiError)) {
  let request =
    api_client.get("/api/stats", sysstats.decoder())
    |> promise.await(hold_network_error)

  promise.race_list([
    request,
    promise.wait(request_timeout_ms)
      |> promise.map(fn(_) {
        Error(error.FetchError(fetch.NetworkError("Request timed out")))
      }),
  ])
}

fn hold_network_error(
  result: Result(SystemStats, ApiError),
) -> Promise(Result(SystemStats, ApiError)) {
  case result {
    Error(error.FetchError(fetch.NetworkError(_))) ->
      promise.wait(request_timeout_ms)
      |> promise.map(fn(_) { result })
    _ -> promise.resolve(result)
  }
}

pub type ServerStatus {
  Checking
  Alive
  ServerUnreachable(detail: String)
  ServerDown(status: Int)
  RequestRejected(status: Int)
  InvalidResponse(detail: String)
  ClientError(detail: String)
}

pub fn server_status(error: ApiError) -> ServerStatus {
  case error {
    error.UnexpectedStatus(status) if status >= 500 && status < 600 ->
      ServerDown(status)
    error.UnexpectedStatus(status) -> RequestRejected(status)
    error.FetchError(fetch.NetworkError(detail)) -> ServerUnreachable(detail)
    error.FetchError(fetch.UnableToReadBody) ->
      InvalidResponse("Unable to read the response body")
    error.FetchError(fetch.InvalidJsonBody) ->
      InvalidResponse("The response body is not valid JSON")
    error.DecodeError(errors) ->
      InvalidResponse(
        "Response did not match the expected stats shape ("
        <> int.to_string(list.length(errors))
        <> " decoding errors)",
      )
    error.InvalidUrl(url) -> ClientError("Invalid API URL: " <> url)
  }
}
