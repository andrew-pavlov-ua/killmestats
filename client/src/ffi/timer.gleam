import lustre/effect.{type Effect}

pub fn after(milliseconds: Int, message: message) -> Effect(message) {
  effect.from(fn(dispatch) {
    set_timeout(milliseconds, fn() { dispatch(message) })
  })
}

@external(javascript, "./timer_ffi.mjs", "set_timeout")
fn set_timeout(milliseconds: Int, callback: fn() -> Nil) -> Nil
