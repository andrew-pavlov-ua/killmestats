export function set_timeout(milliseconds, callback) {
  globalThis.setTimeout(callback, milliseconds);
}
