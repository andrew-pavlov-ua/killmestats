import data
import db/queries
import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/string
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import log
import pog
import sysstats

pub fn interval_seconds() -> Int {
  60 * 60
}

// Floor to the start of its sampling interval; do not round to the nearest one.
pub fn sample_timestamp(now: Timestamp) -> Timestamp {
  let #(seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(now)
  let bucket_seconds = seconds / interval_seconds() * interval_seconds()

  timestamp.from_unix_seconds(bucket_seconds)
}

pub type Context {
  Context(
    cache: table.Table(timestamp.Timestamp, sysstats.SystemStats),
    db: pog.Connection,
  )
}

pub fn init_cache(
  db_opt: option.Option(pog.Connection),
) -> Result(table.Table(Timestamp, sysstats.SystemStats), table.EtsError) {
  let assert Ok(table) = create_cache()

  // load cache from the db
  case db_opt {
    Some(db) -> load_cache(table, db)
    None -> table
  }

  Ok(table)
}

fn load_cache(
  cache: table.Table(timestamp.Timestamp, sysstats.SystemStats),
  db: pog.Connection,
) {
  let samples_list = case queries.get_all_samples(db) {
    Ok(list) -> list
    Error(error) -> {
      log.error(
        "load_cache: error loading stats from postgres: "
        <> query_error_to_string(error),
      )
      []
    }
  }

  list.each(samples_list, fn(stats_sample) {
    let sampled_at = timestamp_from_milliseconds(stats_sample.timestamp_ms)
    insert_sample(cache, stats_sample.stats, sampled_at)
  })

  cache
}

pub fn query_error_to_string(error: pog.QueryError) -> String {
  case error {
    pog.ConstraintViolated(message, constraint, detail) ->
      "Constraint violated ["
      <> constraint
      <> "]: "
      <> message
      <> " ("
      <> detail
      <> ")"
    pog.PostgresqlError(code, name, message) ->
      "Postgres error " <> code <> " (" <> name <> "): " <> message
    pog.UnexpectedArgumentCount(expected, got) ->
      "Unexpected argument count: expected "
      <> int.to_string(expected)
      <> ", got "
      <> int.to_string(got)
    pog.UnexpectedArgumentType(expected, got) ->
      "Unexpected argument type: expected " <> expected <> ", got " <> got
    pog.UnexpectedResultType(errors) ->
      "Unexpected result type (decode error): "
      <> list.map(errors, fn(error) {
        "expected "
        <> error.expected
        <> ", got "
        <> error.found
        <> " at "
        <> string.join(error.path, "/")
      })
      |> string.join("; ")
    pog.QueryTimeout -> "Query timed out"
    pog.ConnectionUnavailable -> "Database connection unavailable"
  }
}

fn timestamp_from_milliseconds(milliseconds: Int) -> Timestamp {
  let seconds = milliseconds / 1000
  let remaining_milliseconds = milliseconds - seconds * 1000

  timestamp.from_unix_seconds_and_nanoseconds(
    seconds,
    remaining_milliseconds * 1_000_000,
  )
}

fn create_cache() -> Result(
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
  cache: table.Table(timestamp.Timestamp, sysstats.SystemStats),
  stats: sysstats.SystemStats,
  now: Timestamp,
) -> Result(Nil, table.EtsError) {
  let bucket = sample_timestamp(now)

  case operations.insert_new(cache, bucket, stats) {
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

pub fn read_whole_cache(
  cache: table.Table(timestamp.Timestamp, sysstats.SystemStats),
) -> List(data.TimeStats) {
  operations.to_list(cache)
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

pub fn delete_expired(
  cache: table.Table(timestamp.Timestamp, sysstats.SystemStats),
) -> Nil {
  delete_expired_at(cache, timestamp.system_time())
}

pub fn delete_expired_at(
  cache: table.Table(timestamp.Timestamp, sysstats.SystemStats),
  now: Timestamp,
) -> Nil {
  let expiration = entry_expiration()

  operations.to_list(cache)
  |> list.each(fn(pair) {
    let #(key, _) = pair
    // `difference(left, right)` calculates right - left.
    let age = timestamp.difference(key, now)

    case duration.compare(age, expiration) {
      order.Gt -> {
        case operations.delete(cache, key) {
          Ok(_) -> Nil
          Error(_) -> log.warning("Failed to delete expired cache entry")
        }
      }
      _ -> Nil
    }
  })
}
