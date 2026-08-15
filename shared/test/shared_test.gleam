import data
import gleam/json
import gleeunit
import sysstats

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn data_json_round_trip_test() {
  let stats =
    sysstats.SystemStats(
      cpu_load: 12.5,
      ram_load: 48.7,
      ram_used_bytes: 8_036_286_464,
      ram_total_bytes: 17_179_869_184,
    )
  let payload =
    data.Data(latest_stats: stats, time_stats_list: [
      data.TimeStats(timestamp_ms: 1_700_000_000_000, stats:),
    ])

  let encoded = payload |> data.to_json |> json.to_string
  let assert Ok(decoded) = json.parse(encoded, data.decoder())
  assert decoded == payload
}
