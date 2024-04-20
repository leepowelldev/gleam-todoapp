import gleam/string
import envoy
import sqlight.{type Connection}

pub fn connect(next: fn(Connection) -> a) -> a {
  let assert Ok(url) = envoy.get("DATABASE_URL")
  let path = string.replace(url, "sqlite:", "file:")
  use conn <- sqlight.with_connection(path)
  next(conn)
}
