import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}

pub type SystemStats {
  SystemStats(
    cpu_load: Float,
    ram_load: Float,
    ram_used_bytes: Int,
    ram_total_bytes: Int,
  )
}

pub fn decoder() -> Decoder(SystemStats) {
  use cpu_load <- decode.field("cpu_load", decode.float)
  use ram_load <- decode.field("ram_load", decode.float)
  use ram_used_bytes <- decode.field("ram_used_bytes", decode.int)
  use ram_total_bytes <- decode.field("ram_total_bytes", decode.int)

  decode.success(SystemStats(
    cpu_load:,
    ram_load:,
    ram_used_bytes:,
    ram_total_bytes:,
  ))
}

pub fn to_json(stats: SystemStats) -> Json {
  json.object([
    #("cpu_load", json.float(stats.cpu_load)),
    #("ram_load", json.float(stats.ram_load)),
    #("ram_used_bytes", json.int(stats.ram_used_bytes)),
    #("ram_total_bytes", json.int(stats.ram_total_bytes)),
  ])
}

pub fn print(stats: SystemStats) -> String {
  stats
  |> to_json
  |> json.to_string
}
