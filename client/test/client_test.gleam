import app/extra_websocket
import app/state
import app/update
import gleam/int
import gleam/list
import gleam/option.{None}
import gleeunit
import sysstats
import ui/charts

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn chart_values_append_latest_sample_test() {
  assert charts.values([1, 2], int.to_float, 3.0) == [1.0, 2.0, 3.0]
}

pub fn add_connection_prepends_new_connection_test() {
  let model = model_with_connections([state.Connecting(7)], 8)
  let #(updated, _) = extra_websocket.add_connection_at(model, "/api/ws")

  assert updated.connections == [state.Connecting(8), state.Connecting(7)]
  assert updated.next_connection_id == 9
}

pub fn remove_connection_keeps_primary_when_no_extras_exist_test() {
  let model = model_with_connections([], 0)
  let #(updated, _) = extra_websocket.remove_connection(model)

  assert updated.connections == []
  assert updated.next_connection_id == 0
}

pub fn set_connection_count_grows_to_requested_total_test() {
  let model = model_with_connections([], 0)
  let #(updated, _) =
    extra_websocket.set_connection_count_at(model, "4", "/api/ws")

  assert list.length(updated.connections) == 3
  assert updated.next_connection_id == 3
}

pub fn set_connection_count_clamps_to_one_test() {
  let model =
    model_with_connections(
      [state.Connecting(3), state.Connecting(2), state.Connecting(1)],
      4,
    )
  let #(updated, _) =
    extra_websocket.set_connection_count_at(model, "0", "/api/ws")

  assert updated.connections == []
}

pub fn invalid_connection_count_does_not_change_model_test() {
  let model = model_with_connections([state.Connecting(1)], 2)
  let #(updated, _) =
    extra_websocket.set_connection_count_at(model, "many", "/api/ws")

  assert updated.connections == model.connections
  assert updated.next_connection_id == model.next_connection_id
}

pub fn stale_primary_timeout_is_ignored_test() {
  let model = state.Model(..base_model(), primary_connection_id: 5)
  let #(updated, _) = update.update(model, state.ConnectionTimedOut(4))

  assert updated.primary_connection_id == 5
  assert updated.connection_timed_out == False
  assert updated.server_status == state.Checking
}

pub fn current_primary_timeout_advances_attempt_test() {
  let model = state.Model(..base_model(), primary_connection_id: 5)
  let #(updated, _) = update.update(model, state.ConnectionTimedOut(5))

  assert updated.primary_connection_id == 6
  assert updated.connection_timed_out == True
  assert updated.server_status
    == state.ServerUnreachable("WebSocket connection timed out")
}

fn model_with_connections(
  connections: List(state.Connection),
  next_connection_id: Int,
) -> state.Model {
  state.Model(
    ..base_model(),
    connections: connections,
    next_connection_id: next_connection_id,
  )
}

fn base_model() -> state.Model {
  state.Model(
    page: state.Home,
    stats: sysstats.SystemStats(
      cpu_load: 0.0,
      ram_load: 0.0,
      ram_used_bytes: 0,
      ram_total_bytes: 0,
    ),
    server_status: state.Checking,
    terminal_lines: [],
    connection_timed_out: False,
    socket: None,
    primary_connection_id: 0,
    connections: [],
    next_connection_id: 0,
  )
}
