import data
import gleam/dynamic/decode
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import pog
import sysstats

pub fn insert_stats_sample(
  db: pog.Connection,
  sample: sysstats.SystemStats,
  now: timestamp.Timestamp,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let sql_query =
    "
  INSERT INTO stats_samples
  (sampled_at, cpu_load, ram_load, ram_used_bytes, ram_total_bytes)
  VALUES ($1, $2, $3, $4, $5)
  ON CONFLICT (sampled_at) DO NOTHING"

  pog.query(sql_query)
  |> pog.parameter(pog.timestamp(now))
  |> pog.parameter(pog.float(sample.cpu_load))
  |> pog.parameter(pog.float(sample.ram_load))
  |> pog.parameter(pog.int(sample.ram_used_bytes))
  |> pog.parameter(pog.int(sample.ram_total_bytes))
  |> pog.execute(db)
}

pub fn delete_expired(
  db: pog.Connection,
  expiration: timestamp.Timestamp,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let sql_query =
    "
  DELETE FROM stats_samples
  WHERE sampled_at <= $1"

  pog.query(sql_query)
  |> pog.parameter(pog.timestamp(expiration))
  |> pog.execute(db)
}

pub fn get_all_samples(
  db: pog.Connection,
) -> Result(List(data.TimeStats), pog.QueryError) {
  let sql_query =
    "
    SELECT
      sampled_at,
      cpu_load,
      ram_load,
      ram_used_bytes,
      ram_total_bytes
    FROM stats_samples
    ORDER BY sampled_at ASC"

  pog.query(sql_query)
  |> pog.returning(time_stats_row_decoder())
  |> pog.execute(db)
  |> result.map(fn(returned) { returned.rows })
}

pub fn user_exists_ip(
  db: pog.Connection,
  ip_address: String,
) -> Result(Bool, pog.QueryError) {
  "
  SELECT EXISTS (
    SELECT 1
    FROM users
    WHERE ip_address = $1::text::inet
  )
  "
  |> pog.query
  |> pog.parameter(pog.text(ip_address))
  |> pog.returning(user_exists_decoder())
  |> pog.execute(db)
  |> result.map(fn(returned) {
    case returned.rows {
      [exists] -> exists
      _ -> False
    }
  })
}

pub fn insert_user_ip(
  db: pog.Connection,
  ip_address: String,
) -> Result(Nil, pog.QueryError) {
  "
  INSERT INTO users (ip_address)
  VALUES ($1::text::inet)
  ON CONFLICT (ip_address) DO NOTHING
  "
  |> pog.query
  |> pog.parameter(pog.text(ip_address))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}

fn user_exists_decoder() -> decode.Decoder(Bool) {
  use exists <- decode.field(0, decode.bool)
  decode.success(exists)
}

fn time_stats_row_decoder() -> decode.Decoder(data.TimeStats) {
  use sampled_at <- decode.field(0, timestamp_decoder())
  use cpu_load <- decode.field(1, decode.float)
  use ram_load <- decode.field(2, decode.float)
  use ram_used_bytes <- decode.field(3, decode.int)
  use ram_total_bytes <- decode.field(4, decode.int)

  let #(seconds, nanoseconds) =
    timestamp.to_unix_seconds_and_nanoseconds(sampled_at)

  let timestamp_ms = seconds * 1000 + nanoseconds / 1_000_000

  decode.success(data.TimeStats(
    timestamp_ms:,
    stats: sysstats.SystemStats(
      cpu_load:,
      ram_load:,
      ram_used_bytes:,
      ram_total_bytes:,
    ),
  ))
}

fn timestamp_decoder() -> decode.Decoder(timestamp.Timestamp) {
  decode.one_of(pog.timestamp_decoder(), [
    {
      use date <- decode.field(0, pog.calendar_date_decoder())
      use time <- decode.field(1, pog.calendar_time_of_day_decoder())

      decode.success(timestamp.from_calendar(
        date:,
        time:,
        offset: calendar.utc_offset,
      ))
    },
  ])
}
