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

export function maxSocketConnections() {
  const raw = globalThis.__KILLMESTATS_CONFIG__?.maxConnections;
  const maxConnections = Number.parseInt(raw, 10);

  return Number.isInteger(maxConnections) && maxConnections > 0
    ? maxConnections
    : 1000;
}
