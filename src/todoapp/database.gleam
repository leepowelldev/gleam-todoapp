import sqlight.{type Connection}
import todoapp/error.{type AppError}
import gleam/result

pub fn with_connection(name: String, next: fn(Connection) -> a) -> a {
  use conn <- sqlight.with_connection(name)
  let assert Ok(_) = sqlight.exec("pragma foreign_keys = on;", conn)
  next(conn)
}

// Run some idempotent DDL to ensure we have the PostgreSQL database schema
// that we want. This should be run when the application starts.
pub fn migrate_schema(db: Connection) -> Result(Nil, AppError) {
  let sql =
    "
  CREATE TABLE IF NOT EXISTS items (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,

    created_at TEXT NOT NULL
      DEFAULT CURRENT_TIMESTAMP,

    updated_at TEXT NOT NULL
      DEFAULT CURRENT_TIMESTAMP,

    content TEXT
      NOT NULL
      CONSTRAINT empty_content CHECK (content != ''),

    completed INTEGER
      NOT NULL
      DEFAULT 0
  ) strict;

  INSERT OR IGNORE INTO items (id, content)
  SELECT 1, 'Collect shopping'
  WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1);
  "

  sqlight.exec(sql, db)
  |> result.map_error(error.SqlightError)
}
