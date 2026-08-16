import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}

import sysstats

pub type Data {
  // The latest sample is shown in the CPU and RAM cards.
  // Timestamped samples are used for the history chart.
  Data(latest_stats: sysstats.SystemStats, time_stats_list: List(TimeStats))
}

pub type TimeStats {
  TimeStats(timestamp_ms: Int, stats: sysstats.SystemStats)
}

fn encode_time_stats(ts: TimeStats) -> Json {
  json.object([
    #("timestamp_ms", json.int(ts.timestamp_ms)),
    #("systemStats", sysstats.to_json(ts.stats)),
  ])
}

pub fn to_json(data: Data) -> Json {
  let time_stats_json = json.array(data.time_stats_list, of: encode_time_stats)

  json.object([
    #(
      "data",
      json.object([
        #("latestStats", sysstats.to_json(data.latest_stats)),
        #("timeStatsList", time_stats_json),
      ]),
    ),
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

  use latest_stats <- decode.subfield(
    ["data", "latestStats"],
    sysstats.decoder(),
  )

  decode.success(Data(time_stats_list:, latest_stats:))
}
