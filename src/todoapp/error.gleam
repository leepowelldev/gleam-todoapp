import sqlight

pub type AppError {
  NotFound
  MethodNotAllowed
  UserNotFound
  BadRequest
  UnprocessableEntity
  ContentRequired
  Unexpected
  ValidationError(#(String, String))
  SqlightError(sqlight.Error)
}
