export function defaultApiHost() {
  const isDevServer =
    globalThis.location?.hostname === "localhost" &&
    globalThis.location?.port === "1234";

  if (isDevServer) {
    return "http://localhost:8000";
  }

  return "";
}
