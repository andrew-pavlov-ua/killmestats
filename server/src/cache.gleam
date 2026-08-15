import data
import dream_ets/config
import dream_ets/table
import sysstats
import dream_ets/operations
import gleam/dynamic
import gleam/dynamic/decode
import gleam/time/timestamp.{type Timestamp}
import gleam/list

pub type Context {
  Context(cache: table.Table(timestamp.Timestamp, sysstats.SystemStats))
}

pub fn create_cache() -> Result(
  table.Table(Timestamp, sysstats.SystemStats),
  table.EtsError,
) {
  config.new("user_cache")
  |> config.table_type(config.table_type_ordered_set())
  |> config.key(timestamp_encoder, timestamp_decoder())
  |> config.value(stats_encoder, sysstats.decoder())
  |> config.create()
}


pub fn cache_system_stats(
  context: Context,
  stats: sysstats.SystemStats,
) -> Result(Bool, table.EtsError) {
  let now = timestamp.system_time()
  let #(unix_seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(now)

  // the same as unix_seconds - { unix_seconds % 60 }
  let minute_seconds = unix_seconds / 60 * 60
  let minute = timestamp.from_unix_seconds(minute_seconds)

  operations.insert_new(context.cache, minute, stats)
}

fn timestamp_encoder(value: Timestamp) -> dynamic.Dynamic {
  let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(value)

  dynamic.array([
    dynamic.int(seconds),
    dynamic.int(nanoseconds),
  ])
}

fn timestamp_decoder() -> decode.Decoder(Timestamp) {
  use seconds <- decode.field(0, decode.int)
  use nanoseconds <- decode.field(1, decode.int)

  decode.success(timestamp.from_unix_seconds_and_nanoseconds(
    seconds,
    nanoseconds,
  ))
}

fn stats_encoder(stats: sysstats.SystemStats) -> dynamic.Dynamic {
  dynamic.properties([
    #(dynamic.string("cpu_load"), dynamic.float(stats.cpu_load)),
    #(dynamic.string("ram_load"), dynamic.float(stats.ram_load)),
    #(dynamic.string("ram_used_bytes"), dynamic.int(stats.ram_used_bytes)),
    #(dynamic.string("ram_total_bytes"), dynamic.int(stats.ram_total_bytes)),
    // add more stats
  ])
}

pub fn read_whole_cache(context: Context) -> data.Data {
  let pairs = operations.to_list(context.cache)

  let time_stats_list =
    list.map(pairs, fn(pair) {
      let #(key, value) = pair
      let #(seconds, nanoseconds) =
        timestamp.to_unix_seconds_and_nanoseconds(key)

      let timestamp_ms =
      seconds * 1000 + nanoseconds / 1_000_000

      data.TimeStats(
        timestamp_ms:,
        stats: value,
      )
    })

  data.Data(time_stats_list:)
}
