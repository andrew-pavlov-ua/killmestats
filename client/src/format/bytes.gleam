import gleam/float
import gleam/int

const kibibyte = 1024

const mebibyte = 1_048_576

const gibibyte = 1_073_741_824

pub fn human_readable(bytes: Int, add_suffix: Bool) -> String {
  case bytes {
    bytes if bytes >= gibibyte ->
      case add_suffix {
        True -> format(bytes, gibibyte, "GiB")
        False -> format(bytes, gibibyte, "")
      }

    bytes if bytes >= mebibyte ->
      case add_suffix {
        True -> format(bytes, mebibyte, "MiB")
        False -> format(bytes, mebibyte, "")
      }
    bytes if bytes >= kibibyte ->
      case add_suffix {
        True -> format(bytes, kibibyte, "KiB")
        False -> format(bytes, kibibyte, "")
      }

    bytes ->
      int.to_string(bytes)
      <> case add_suffix {
        True -> " B"
        False -> ""
      }
  }
}

pub fn compact_gibibytes(bytes: Int, round_up: Bool) -> String {
  let value = int.to_float(bytes) /. int.to_float(gibibyte)
  // Capacity is rounded up so the compact total never understates installed RAM.
  let rounded = case round_up {
    True -> value |> float.ceiling |> float.truncate |> int.to_string
    False -> value |> float.round |> int.to_string
  }

  rounded
}

pub fn gibibytes(bytes: Int) -> String {
  format(bytes, gibibyte, "")
}

fn format(bytes: Int, unit: Int, suffix: String) -> String {
  let value = int.to_float(bytes) /. int.to_float(unit)

  let rounded =
    value *. 100.0
    |> float.round
    |> int.to_float
    |> fn(value) { value /. 100.0 }

  float.to_string(rounded) <> suffix
}
