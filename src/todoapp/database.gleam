import sqlight.{type Connection}
import todoapp/error.{type AppError}
import gleam/result

pub fn with_connection(name: String, next: fn(Connection) -> value) -> value {
  use conn <- sqlight.with_connection(name)
  let assert Ok(_) = sqlight.exec("pragma foreign_keys = on;", conn)
  next(conn)
}

// Run some idempotent DDL to ensure we have the PostgreSQL database schema
// that we want. This should be run when the application starts.
pub fn migrate_schema(db: Connection) -> Result(Nil, AppError) {
  let sql =
    "
  create table if not exists items (
    id integer primary key autoincrement not null,

    created_at text not null
      default current_timestamp,

    updated_at text not null
      default current_timestamp,

    content text
      not null
      constraint empty_content check (content != ''),

    completed integer
      not null
      default 0
  ) strict;

  insert or ignore into items (id, content)
  select 1, 'Collect shopping'
  where not exists (select 1 from items where id = 1);
  "

  sqlight.exec(sql, db)
  |> result.map_error(error.SqlightError)
}
