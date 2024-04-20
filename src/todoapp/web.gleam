import gleam/io
import gleam/int
import wisp.{type Response}
import sqlight
import todoapp/error.{type AppError}

pub type Context {
  Context(db: sqlight.Connection)
}

pub fn error_to_response(error: AppError) -> Response {
  case error {
    error.NotFound -> wisp.not_found()
    error.UnprocessableEntity -> wisp.unprocessable_entity()
    error.Unexpected(error) -> {
      io.debug(error)
      wisp.internal_server_error()
    }
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
    Error(error) -> error_to_response(error)
  }
}

pub fn require_int_param(param: String, next: fn(Int) -> Response) {
  case int.parse(param) {
    Ok(value) -> next(value)
    Error(_) -> wisp.not_found()
  }
}
