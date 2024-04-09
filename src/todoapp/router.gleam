import gleam/http
import gleam/result
import wisp.{type Request, type Response}
import todoapp/web.{type Context}
import todoapp/error
import todoapp/item

pub fn with_handle_request(request: Request, context: Context) -> Response {
  case wisp.path_segments(request) {
    [] -> home(request, context)
    ["add"] -> add(request, context)
    ["update"] -> update(request, context)
    ["delete", id] -> delete(id, request, context)
    _ -> wisp.not_found()
  }
}

fn home(request: Request, context: Context) -> Response {
  use <- wisp.require_method(request, http.Get)

  let result = {
    use items <- result.try(item.get_all(context.db))
    Ok(item.all_to_json(items))
  }

  use json <- web.require_ok(result)

  wisp.json_response(json, 200)
}

fn add(request: Request, context: Context) -> Response {
  wisp.set_max_body_size(request, 500)

  use <- wisp.require_method(request, http.Post)
  use json <- wisp.require_json(request)

  let result = {
    use data <- result.try(
      item.decode_create_dto(json)
      |> result.replace_error(error.UnprocessableEntity),
    )
    use item <- result.try(item.insert(data, context.db))
    Ok(item.to_json(item))
  }

  use json <- web.require_ok(result)

  wisp.json_response(json, 201)
}

fn update(request: Request, context: Context) -> Response {
  wisp.set_max_body_size(request, 500)

  use <- wisp.require_method(request, http.Patch)
  use json <- wisp.require_json(request)

  let result = {
    use data <- result.try(
      item.decode_update_dto(json)
      |> result.replace_error(error.UnprocessableEntity),
    )
    use item <- result.try(item.update(data, context.db))
    Ok(item.to_json(item))
  }

  use json <- web.require_ok(result)

  wisp.json_response(json, 200)
}

fn delete(id: String, request: Request, context: Context) -> Response {
  use <- wisp.require_method(request, http.Delete)
  use id <- web.require_int_param(id)

  let result = {
    use item <- result.try(item.delete(id, context.db))
    Ok(item)
  }

  use _ <- web.require_ok(result)

  wisp.no_content()
}
