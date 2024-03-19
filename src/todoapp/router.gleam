import gleam/http
import gleam/io
import gleam/result
import gleam/dynamic.{type Dynamic}
import gleam/json
import gleam/string_builder
import gleam/http/response
import wisp.{type Request, type Response}
import todoapp/web.{type Context}
import todoapp/error.{type AppError}
import todoapp/item.{type CreateItemDto, type Item}
import valid
import valid/string as valid_string
import sqlight

pub fn with_handle_request(request: Request, context: Context) -> Response {
  case wisp.path_segments(request) {
    [] -> home(request, context)
    ["add"] -> add(request, context)
    _ -> wisp.not_found()
  }
}

fn home(request: Request, context: Context) -> Response {
  use <- wisp.require_method(request, http.Get)

  case item.get_items(context.db) {
    Ok(items) -> {
      let json_data = item.encode_items(items)

      wisp.ok()
      |> wisp.json_body(json.to_string_builder(json_data))
    }
    Error(error) -> {
      io.debug(error)
      wisp.internal_server_error()
    }
  }
}

fn add(request: Request, context: Context) -> Response {
  wisp.set_max_body_size(request, 500)

  use <- wisp.require_method(request, http.Post)
  use json <- wisp.require_json(request)

  case create_item(json, context.db) {
    Ok(item) -> {
      let body = json.to_string_builder(item.encode_item(item))

      wisp.ok()
      |> wisp.json_body(body)
    }
    Error(error.BadRequest) -> wisp.bad_request()
    Error(error.ValidationError(error)) -> {
      let #(t, _) = error
      response.Response(400, [], wisp.Text(string_builder.from_string(t)))
    }
    _ -> wisp.internal_server_error()
  }
}

fn create_item(json: Dynamic, db: sqlight.Connection) -> Result(Item, AppError) {
  Ok(json)
  |> result.try(fn(value) {
    item.decode_create_item_dto(value)
    |> result.replace_error(error.BadRequest)
  })
  |> result.try(fn(value) {
    validate_create_todo_dto(value)
    |> result.map_error(fn(error) {
      let #(first_error, _) = error

      case first_error {
        ContentTooShort -> #("content", "Too short")
        ContentTooLong -> #("content", "Too long")
        ContentEmpty -> #("content", "Empty")
        ContentNotEmail -> #("content", "Not email")
      }
      |> error.ValidationError
    })
  })
  |> result.try(item.insert_item(_, db))
}

pub type ValidateCreateTodoDtoError {
  ContentTooShort
  ContentTooLong
  ContentEmpty
  ContentNotEmail
}

fn validate_create_todo_dto(
  dto: CreateItemDto,
) -> Result(
  CreateItemDto,
  #(ValidateCreateTodoDtoError, List(ValidateCreateTodoDtoError)),
) {
  let content_validator =
    valid.all([
      valid_string.is_not_empty(ContentEmpty),
      valid_string.min_length(ContentTooShort, 1),
      valid_string.max_length(ContentTooLong, 50),
      valid_string.is_email(ContentNotEmail),
    ])

  valid.build1(item.CreateItemDto)
  |> valid.validate(dto.content, content_validator)
}
