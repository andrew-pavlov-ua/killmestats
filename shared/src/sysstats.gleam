import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}

pub type SystemStats {
  SystemStats(cpu_load: Float, ram_load: Float)
}

pub fn decoder() -> Decoder(SystemStats) {
  use cpu_load <- decode.field("cpu_load", decode.float)
  use ram_load <- decode.field("ram_load", decode.float)
  decode.success(SystemStats(cpu_load:, ram_load:))
}

pub fn to_json(stats: SystemStats) -> Json {
  json.object([
    #("cpu_load", json.float(stats.cpu_load)),
    #("ram_load", json.float(stats.ram_load)),
  ])
}
