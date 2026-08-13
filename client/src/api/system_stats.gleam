pub type ServerStatus {
  Checking
  Alive
  ServerUnreachable(detail: String)
}
