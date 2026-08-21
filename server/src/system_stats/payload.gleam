import cache
import context
import data
import gleam/json
import live_users
import system_stats/stats

pub fn encode(context: context.Context, returning_visitor: Bool) -> String {
  data.Data(
    latest_stats: stats.get_system_stats(),
    time_stats_list: cache.read_whole_cache(context.cache),
    live_users: live_users.current(context.live_users_counter),
    returning_visitor:,
  )
  |> data.to_json
  |> json.to_string
}
