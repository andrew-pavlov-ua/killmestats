import gleam/fetch
import gleam/json
import gleam/string

pub type ApiError {
  InvalidUrl(url: String)
  FetchError(fetch.FetchError)
}

pub fn json_decode_message(error: json.DecodeError) -> String {
  case error {
    json.UnexpectedEndOfInput -> "JSON ended before the value was complete"
    json.UnexpectedByte(byte) -> "Unexpected JSON byte: " <> byte
    json.UnexpectedSequence(sequence) ->
      "Unexpected JSON sequence: " <> sequence
    json.UnableToDecode(errors) ->
      "JSON does not match SystemStats: " <> string.inspect(errors)
  }
}
