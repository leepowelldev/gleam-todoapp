import gleeunit
import gleeunit/should
import gleam/result
import gleam/list
import todoapp/item
import sqlight.{type Connection}
import simplifile

pub fn main() {
  gleeunit.main()
}

pub fn get_all_test() {
  use db <- connect()

  let _ =
    sqlight.exec("INSERT INTO items (content) VALUES ('Collect shopping')", db)

  let result = item.get_all(db)
  let items = result.unwrap(result, [])
  let assert Ok(item) = list.first(items)

  should.be_ok(result)
  should.equal(list.length(items), 1)
  should.equal(item.content, "Collect shopping")
}

fn connect(next: fn(Connection) -> a) -> a {
  use conn <- sqlight.with_connection(":memory:")

  let assert Ok(_) = {
    use sql <- result.try(
      simplifile.read("db/schema.sql")
      |> result.nil_error,
    )

    sqlight.exec(sql, conn)
    |> result.nil_error
  }

  next(conn)
}
