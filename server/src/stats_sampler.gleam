import cache
import gleam/erlang/process
import gleam/int
import gleam/otp/actor
import gleam/time/timestamp
import log
import system_stats/stats

type Message {
  Sample
}

pub fn start(context: cache.Context) {
  // The actor shares the ETS table created by the main server process
  let assert Ok(sampler) =
    actor.new(context)
    |> actor.on_message(handle_message)
    |> actor.start()

  // Seed the chart immediately instead of waiting for the next quarter hour
  process.send(sampler.data, Sample)

  // Keep timing outside the actor so it stays free to process sample messages
  process.spawn(fn() {
    process.sleep(schedule_first_sample())
    schedule_next(sampler.data)
  })

  Nil
}

fn handle_message(
  context: cache.Context,
  message: Message,
) -> actor.Next(cache.Context, Message) {
  case message {
    Sample -> {
      // Cleanup runs with sampling, not on every WebSocket history read
      cache.delete_expired(context)

      let system_stats = stats.get_system_stats()

      case cache.insert_sample(context, system_stats) {
        Ok(_) -> Nil
        Error(_) -> log.error("Stats sampler failed to write to ETS")
      }

      actor.continue(context)
    }
  }
}

fn schedule_next(data: process.Subject(Message)) -> Nil {
  // The first call is already aligned; subsequent samples stay interval_seconds() minutes apart
  process.send(data, Sample)
  process.sleep(cache.interval_seconds() * 1000)
  schedule_next(data)
}

// Wait until the next :00, :15, :30, or :45 boundary
fn schedule_first_sample() {
  let interval = cache.interval_seconds()
  let now = timestamp.system_time()
  let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(now)

  let next_boundary_seconds = seconds / interval * interval + interval

  let remaining_seconds = next_boundary_seconds - seconds
  let remaining_milliseconds =
    remaining_seconds * 1000 - nanoseconds / 1_000_000

  int.max(remaining_milliseconds, 1)
}
