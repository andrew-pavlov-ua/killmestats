import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

pub type Push {
  StatsUpdated(payload: String)
}

pub opaque type Hub {
  Hub(subject: Subject(Message))
}

type State {
  State(next_id: Int, clients: Dict(Int, Subject(Push)))
}

type Message {
  Register(client: Subject(Push), reply_to: Subject(Int))
  Unregister(id: Int)
  Broadcast(payload: String)
}

pub fn start() -> Hub {
  let initial = State(next_id: 0, clients: dict.new())
  let assert Ok(started) =
    actor.new(initial)
    |> actor.on_message(handle_message)
    |> actor.start()

  Hub(started.data)
}

pub fn register(hub: Hub, client: Subject(Push)) -> Int {
  let Hub(subject) = hub
  actor.call(subject, waiting: 1000, sending: fn(reply_to) {
    Register(client:, reply_to:)
  })
}

pub fn unregister(hub: Hub, id: Int) -> Nil {
  let Hub(subject) = hub
  actor.send(subject, Unregister(id:))
}

pub fn broadcast(hub: Hub, payload: String) -> Nil {
  let Hub(subject) = hub
  actor.send(subject, Broadcast(payload:))
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Register(client, reply_to) -> {
      let id = state.next_id
      process.send(reply_to, id)
      actor.continue(State(
        next_id: id + 1,
        clients: dict.insert(state.clients, id, client),
      ))
    }

    Unregister(id) ->
      actor.continue(State(..state, clients: dict.delete(state.clients, id)))

    Broadcast(payload) -> {
      state.clients
      |> dict.values
      |> list.each(fn(client) { process.send(client, StatsUpdated(payload:)) })

      actor.continue(state)
    }
  }
}
