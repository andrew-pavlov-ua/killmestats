import ffi/config as config_ffi

pub fn api_base_url() -> String {
  config_ffi.default_api_host()
}

pub fn max_socket_connections() -> Int {
  1000
}
