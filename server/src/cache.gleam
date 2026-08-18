import data
import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import log
import sysstats

pub fn interval_seconds() -> Int {
  15 * 60
}

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

pub fn insert_sample(
  context: Context,
  stats: sysstats.SystemStats,
) -> Result(Nil, table.EtsError) {
  insert_sample_at(context, stats, timestamp.system_time())
}

pub fn insert_sample_at(
  context: Context,
  stats: sysstats.SystemStats,
  now: Timestamp,
) -> Result(Nil, table.EtsError) {
  let #(unix_seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(now)

  let bucket_seconds = unix_seconds / interval_seconds() * interval_seconds()

  let bucket = timestamp.from_unix_seconds(bucket_seconds)

  case operations.insert_new(context.cache, bucket, stats) {
    Ok(True) -> {
      log.info(
        "Inserting stats into cache: "
        <> timestamp.to_http_date(now)
        <> ", cpu: "
        <> float.to_string(stats.cpu_load)
        <> "RAM: "
        <> float.to_string(stats.ram_load),
      )
      Ok(Nil)
    }
    Ok(False) -> Ok(Nil)
    Error(error) -> {
      log.error("handle_cache error: failed to insert stats")
      Error(error)
    }
  }
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
  ])
}

fn entry_expiration() -> duration.Duration {
  duration.hours(24)
}

pub fn read_whole_cache(context: Context) -> List(data.TimeStats) {
  operations.to_list(context.cache)
  |> list.filter_map(fn(pair) {
    let #(key, value) = pair
    // `difference(left, right)` calculates right - left.
    let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(key)

    let timestamp_ms = seconds * 1000 + nanoseconds / 1_000_000

    Ok(data.TimeStats(timestamp_ms:, stats: value))
  })
  |> list.sort(by: fn(stat1, stat2) {
    int.compare(stat1.timestamp_ms, stat2.timestamp_ms)
  })
}

pub fn delete_expired(context: Context) -> Nil {
  delete_expired_at(context, timestamp.system_time())
}

pub fn delete_expired_at(context: Context, now: Timestamp) -> Nil {
  let expiration = entry_expiration()

  operations.to_list(context.cache)
  |> list.each(fn(pair) {
    let #(key, _) = pair
    // `difference(left, right)` calculates right - left.
    let age = timestamp.difference(key, now)

    case duration.compare(age, expiration) {
      order.Gt -> {
        case operations.delete(context.cache, key) {
          Ok(_) -> Nil
          Error(_) -> log.warning("Failed to delete expired cache entry")
        }
      }
      _ -> Nil
    }
  })
}
