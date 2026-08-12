import gleam/http.{Delete, Get, Post}
import gleam/http/response
import gleam/json
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
    |> router.handle_request

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
    |> router.handle_request

  response.status
  |> should.equal(404)
}

pub fn unsupported_api_method_returns_method_not_allowed_test() {
  let response =
    simulate.request(Delete, "/api")
    |> router.handle_request

  response.status
  |> should.equal(405)

  response
  |> response.get_header("allow")
  |> should.equal(Ok("GET, POST"))
}

pub fn panic_endpoint_is_rescued_as_internal_server_error_test() {
  let response =
    simulate.request(Post, "/api/panic")
    |> router.handle_request

  response.status
  |> should.equal(500)
}
