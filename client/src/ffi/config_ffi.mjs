export function apiHost() {
  const value = globalThis.__KILLMESTATS_CONFIG__?.apiHost;
  return typeof value === "string" ? value : "";
}

export function defaultApiHost() {
  const isDevServer =
    globalThis.location?.hostname === "localhost" &&
    globalThis.location?.port === "1234";

  if (isDevServer) {
    return "http://localhost:8000";
  }

  return "";
}
