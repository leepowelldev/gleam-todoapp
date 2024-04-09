import gleam/result
import gleam/io
import gleam/int
import wisp.{type Response}
import sqlight.{type Error as SQLightError}
import todoapp/error.{type AppError}

pub type Context {
  Context(db: sqlight.Connection)
}

pub fn normalize_sql_error(result: Result(a, SQLightError)) {
  result
  |> result.map_error(io.debug)
  |> result.map_error(error.SqlightError)
}

pub fn error_to_response(error: AppError) -> Response {
  case error {
    error.NotFound -> wisp.not_found()
    error.UnprocessableEntity -> wisp.unprocessable_entity()
    error.Unexpected -> wisp.internal_server_error()
    error.SqlightError(error) -> {
      io.debug(error)
      wisp.internal_server_error()
    }
  }
}

pub fn require_ok(
  value: Result(a, AppError),
  next: fn(a) -> Response,
) -> Response {
  case value {
    Ok(value) -> next(value)
    Error(_) -> wisp.internal_server_error()
  }
}

pub fn require_int_param(param: String, next: fn(Int) -> Response) {
  case int.parse(param) {
    Ok(value) -> next(value)
    Error(_) -> wisp.not_found()
  }
}
