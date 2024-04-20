import sqlight

pub type AppError {
  NotFound
  UnprocessableEntity
  Unexpected(String)
  SqlightError(sqlight.Error)
}
