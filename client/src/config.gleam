import ffi/config as config_ffi
import gleam/string

pub fn api_base_url() -> String {
  let api_host = config_ffi.api_host()

  case string.trim(api_host) {
    "" -> config_ffi.default_api_host()
    api_host -> api_host
  }
}

pub fn max_socket_connections() -> Int {
  config_ffi.max_socket_connections()
}
