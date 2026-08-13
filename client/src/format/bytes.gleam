import gleam/float
import gleam/int

const kibibyte = 1024

// KiB
const mebibyte = 1_048_576

// MiB
const gibibyte = 1_073_741_824

// GiB

pub fn human_readable(bytes: Int, add_suddix: Bool) -> String {
  case bytes {
    bytes if bytes >= gibibyte ->
      case add_suddix {
        True -> format(bytes, gibibyte, "GiB")
        False -> format(bytes, gibibyte, "")
      }

    bytes if bytes >= mebibyte ->
      case add_suddix {
        True -> format(bytes, mebibyte, "MiB")
        False -> format(bytes, mebibyte, "")
      }
    bytes if bytes >= kibibyte ->
      case add_suddix {
        True -> format(bytes, kibibyte, "MiB")
        False -> format(bytes, kibibyte, "")
      }

    bytes ->
      int.to_string(bytes)
      <> case add_suddix {
        True -> " B"
        False -> ""
      }
  }
}

pub fn compact_gibibytes(bytes: Int, round_up: Bool) -> String {
  let value = int.to_float(bytes) /. int.to_float(gibibyte)
  let rounded = case round_up {
    True -> value |> float.ceiling |> float.truncate |> int.to_string
    False -> value |> float.round |> int.to_string
  }

  rounded
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
