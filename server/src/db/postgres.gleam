import envoy
import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/result
import gleam/string
import pog

type DBConfig {
  DBConfig(db_host: String, db_name: String, db_user: String, db_pass: String)
}

fn pool_name() {
  process.new_name("killmestats_db_pool")
}

fn get_env_conf() -> DBConfig {
  let db_host = envoy.get("POSTGRES_HOST") |> result.unwrap("postgres")
  let db_name = envoy.get("POSTGRES_DB") |> result.unwrap("stats")
  let db_user = envoy.get("POSTGRES_USER") |> result.unwrap("postgres")
  let db_pass = envoy.get("POSTGRES_PASSWORD") |> result.unwrap("postgres")

  DBConfig(db_host:, db_name:, db_user:, db_pass:)
}

pub fn init_db() -> Result(pog.Connection, actor.StartError) {
  let config = get_env_conf()
  let name = pool_name()

  let pool_child =
    pog.default_config(name)
    |> pog.host(config.db_host)
    |> pog.database(config.db_name)
    |> pog.user(config.db_user)
    |> pog.password(string.to_option(config.db_pass))
    |> pog.pool_size(15)
    |> pog.supervised

  case
    supervisor.new(supervisor.RestForOne)
    |> supervisor.add(pool_child)
    |> supervisor.start
  {
    Ok(_) -> Ok(pog.named_connection(name))
    Error(error) -> Error(error)
  }
}
