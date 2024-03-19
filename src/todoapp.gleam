import dotenv_gleam
import mist
import gleam/erlang/process
import gleam/erlang/os
import gleam/result
import gleam/int
import wisp
import todoapp/router
import todoapp/database
import todoapp/web

pub fn main() {
  dotenv_gleam.config()
  wisp.configure_logger()

  // TODO create a new connection per request?
  use db <- database.with_connection("file:database.db")
  let assert Ok(_) = database.migrate_schema(db)

  let assert Ok(port) =
    os.get_env("PORT")
    |> result.try(int.parse)

  let assert Ok(secret_key) = os.get_env("SECRET_KEY")

  let context = web.Context(db: db)

  let handler = router.with_handle_request(_, context)

  let assert Ok(_) =
    handler
    |> wisp.mist_handler(secret_key)
    |> mist.new
    |> mist.port(port)
    |> mist.start_http

  process.sleep_forever()
}
