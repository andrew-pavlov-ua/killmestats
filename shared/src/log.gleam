import gleam/io

pub fn debug(message: String) -> Nil {
  io.println("[DEBUG] " <> message)
}

pub fn info(message: String) -> Nil {
  io.println("[INFO] " <> message)
}

pub fn warning(message: String) -> Nil {
  io.println_error("[WARNING] " <> message)
}

pub fn error(message: String) -> Nil {
  io.println_error("[ERROR] " <> message)
}
