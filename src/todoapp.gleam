import mist
import gleam/erlang/process
import wisp
import dot_env
import envoy
import todoapp/router
import todoapp/database
import todoapp/web

pub fn main() {
  dot_env.load()
  wisp.configure_logger()

  let assert Ok(secret_key) = envoy.get("SECRET_KEY")

  use db <- database.connect()

  let context = web.Context(db: db)

  let assert Ok(_) =
    router.handle_request(_, context)
    |> wisp.mist_handler(secret_key)
    |> mist.new
    |> mist.port(8776)
    |> mist.start_http

  process.sleep_forever()
}
