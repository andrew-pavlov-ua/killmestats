import gleam/io
import gleam/json
import shared.{type SystemStats}
import wisp.{type Response}

pub fn get_stats() -> Response {
  let stats: SystemStats = get_system_stats()

  // complicated json object
  // let body =
  //   json.object([
  //     #("systemStats", json.object([
  //       #("cpu_load", json.float(stats.cpu_load)),
  //       #("ram_load", json.float(stats.ram_load)),
  //     ])),
  //   ])
  //   |> json.to_string

  let body =
    json.object([
      #("cpu_load", json.float(stats.cpu_load)),
      #("ram_load", json.float(stats.ram_load)),
    ])
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(body)
}

// "stats" - the erlang module; "cpu_load" - the erlang function to call
@external(erlang, "stats", "cpu_load")
fn cpu_load() -> Float

@external(erlang, "stats", "ram_load")
fn ram_load() -> Float

fn get_system_stats() -> SystemStats {
  let cpu_load = cpu_load()
  let ram_load = ram_load()

  case cpu_load == 0.0 {
    True ->
      io.print_error(
        "Warning: CPU load is 0%; the system may be idle, or os_mon/cpu_sup may be unavailable.\n",
      )
    False -> Nil
  }

  case ram_load == 0.0 {
    True ->
      io.print_error(
        "Warning: RAM load is 0%; os_mon/memsup may be unavailable or may have failed to read system memory.\n",
      )
    False -> Nil
  }

  // same as shared.SystemStats(cpu_load: cpu_load, ram_load: ram_load)
  shared.SystemStats(cpu_load:, ram_load:)
}
