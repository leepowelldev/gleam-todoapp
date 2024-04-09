import sqlight

pub type AppError {
  NotFound
  UnprocessableEntity
  Unexpected
  SqlightError(sqlight.Error)
}
