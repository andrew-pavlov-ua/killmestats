import cache
import data
import dream_ets/operations
import gleam/http.{Delete, Get, Post}
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/time/duration
import gleam/time/timestamp
import gleeunit
import gleeunit/should
import router
import sysstats
import system_stats/stats
import wisp.{Text}
import wisp/simulate

pub fn main() -> Nil {
  gleeunit.main()
}

fn handle_request(req) {
  router.handle_request(req)
}

pub fn system_stats_are_percentages_test() {
  let system_stats = stats.get_system_stats()

  should.be_true(system_stats.cpu_load >=. 0.0)
  should.be_true(system_stats.cpu_load <=. 100.0)
  should.be_true(system_stats.ram_load >=. 0.0)
  should.be_true(system_stats.ram_load <=. 100.0)
}

pub fn stats_endpoint_test() {
  let response =
    simulate.request(Get, "/api/stats")
    |> handle_request

  response.status
  |> should.equal(200)

  response
  |> response.get_header("content-type")
  |> should.equal(Ok("application/json; charset=utf-8"))

  let assert Text(body) = response.body
  let decoded = json.parse(body, sysstats.decoder())
  let system_stats = should.be_ok(decoded)

  should.be_true(system_stats.cpu_load >=. 0.0)
  should.be_true(system_stats.ram_load >=. 0.0)
}

pub fn unknown_route_returns_not_found_test() {
  let response =
    simulate.request(Get, "/not-a-route")
    |> handle_request

  response.status
  |> should.equal(404)
}

pub fn unsupported_api_method_returns_method_not_allowed_test() {
  let response =
    simulate.request(Delete, "/api")
    |> handle_request

  response.status
  |> should.equal(405)

  response
  |> response.get_header("allow")
  |> should.equal(Ok("GET, POST"))
}

pub fn panic_endpoint_is_rescued_as_internal_server_error_test() {
  let response =
    simulate.request(Post, "/api/panic")
    |> handle_request

  response.status
  |> should.equal(500)
}

fn sample(cpu_load: Float) -> sysstats.SystemStats {
  sysstats.SystemStats(
    cpu_load: cpu_load,
    ram_load: 50.0,
    ram_used_bytes: 500,
    ram_total_bytes: 1000,
  )
}

pub fn sampler_timestamps_are_floored_to_the_sampling_interval_test() {
  let sampled_at =
    timestamp.from_unix_seconds_and_nanoseconds(1_800_000_999, 123_000_000)

  cache.sample_timestamp(sampled_at)
  |> timestamp.to_unix_seconds_and_nanoseconds
  |> should.equal(#(1_800_000_000, 0))
}

pub fn cache_keeps_first_sample_in_each_interval_test() {
  let assert Ok(table) = cache.init_cache(None)
  let now = timestamp.from_unix_seconds(1_800_000_123)
  let first = sample(12.0)
  let later = sample(34.0)

  cache.insert_sample(table, first, now)
  |> should.be_ok
  cache.insert_sample(table, later, timestamp.add(now, duration.minutes(5)))
  |> should.be_ok

  let assert [data.TimeStats(timestamp_ms:, stats: stored)] =
    cache.read_whole_cache(table)

  timestamp_ms
  |> should.equal(1_800_000_000_000)
  stored
  |> should.equal(first)

  operations.delete_table(table)
  |> should.be_ok
}

pub fn cache_history_is_chronological_test() {
  let assert Ok(table) = cache.init_cache(None)
  let earlier = timestamp.from_unix_seconds(1_800_000_000)
  let later = timestamp.add(earlier, duration.minutes(15))

  operations.set(table, later, sample(20.0))
  |> should.be_ok
  operations.set(table, earlier, sample(10.0))
  |> should.be_ok

  let timestamps =
    cache.read_whole_cache(table)
    |> list.map(fn(entry) { entry.timestamp_ms })

  timestamps
  |> should.equal([1_800_000_000_000, 1_800_000_900_000])

  operations.delete_table(table)
  |> should.be_ok
}

pub fn cache_deletes_only_expired_samples_test() {
  let assert Ok(table) = cache.init_cache(None)
  let now = timestamp.from_unix_seconds(1_800_000_000)
  let expired = timestamp.subtract(now, duration.hours(25))
  let retained = timestamp.subtract(now, duration.hours(23))

  operations.set(table, expired, sample(10.0))
  |> should.be_ok
  operations.set(table, retained, sample(20.0))
  |> should.be_ok

  cache.delete_expired_at(table, now)

  let assert [data.TimeStats(stats: remaining, ..)] =
    cache.read_whole_cache(table)
  remaining
  |> should.equal(sample(20.0))

  operations.delete_table(table)
  |> should.be_ok
}
