import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}

import sysstats

pub type Data {
  Data(
    // system_stats: sysstats.SystemStats,

    // the client would show the latest item in this list
    time_stats_list: List(TimeStats)
  )
}

pub type TimeStats {
  TimeStats(
    timestamp_ms: Int,
    stats: sysstats.SystemStats
  )
}

fn encode_time_stats(ts: TimeStats) -> Json {
  json.object([
    #("timestamp_ms", json.int(ts.timestamp_ms)),
    #("systemStats", sysstats.to_json(ts.stats))
  ])
}

pub fn to_json(data: Data) -> Json {
  let list_json_string =
    json.array(data.time_stats_list, of: encode_time_stats)

  json.object([
    #("data",
      json.object([
        #("timeStatsList", list_json_string)
      ])
    )
  ])
}

fn time_stats_decoder() -> Decoder(TimeStats) {
  use timestamp_ms <- decode.field("timestamp_ms", decode.int)
  use stats <- decode.field("systemStats", sysstats.decoder())

  decode.success(TimeStats(timestamp_ms:, stats:))
}

pub fn decoder() -> Decoder(Data) {
  use time_stats_list <- decode.subfield(
    ["data", "timeStatsList"],
    decode.list(of: time_stats_decoder()),
  )

  decode.success(Data(time_stats_list:))
}
