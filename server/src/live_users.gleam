import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/otp/actor

pub opaque type Counter {
  Counter(subject: Subject(Message))
}

type Message {
  Add(reply_to: Subject(Int))
  Remove
  Get(reply_to: Subject(Int))
}

pub fn start() -> Counter {
  let assert Ok(started) =
    actor.new(0)
    |> actor.on_message(handle_message)
    |> actor.start()

  Counter(started.data)
}

pub fn add(counter: Counter) -> Int {
  let Counter(subject) = counter
  actor.call(subject, waiting: 1000, sending: Add)
}

pub fn remove(counter: Counter) -> Nil {
  let Counter(subject) = counter
  actor.send(subject, Remove)
}

pub fn current(counter: Counter) -> Int {
  let Counter(subject) = counter
  actor.call(subject, waiting: 1000, sending: Get)
}

fn handle_message(count: Int, message: Message) -> actor.Next(Int, Message) {
  case message {
    Add(reply_to) -> {
      let next = count + 1
      process.send(reply_to, next)
      actor.continue(next)
    }
    Remove -> actor.continue(int.max(count - 1, 0))
    Get(reply_to) -> {
      process.send(reply_to, count)
      actor.continue(count)
    }
  }
}
