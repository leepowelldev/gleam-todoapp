import gleam/http
import gleam/result
import wisp.{type Request, type Response}
import todoapp/web.{type Context}
import todoapp/error
import todoapp/item

pub fn handle_request(request: Request, context: Context) -> Response {
  use request <- middleware(request, context)

  case wisp.path_segments(request) {
    [] -> index_route(request, context)
    [id] -> item_route(id, request, context)
    _ -> wisp.not_found()
  }
}

pub fn middleware(
  request: wisp.Request,
  _context: Context,
  next: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  use <- wisp.log_request(request)
  use <- wisp.rescue_crashes

  next(request)
}

fn index_route(request: Request, context: Context) -> Response {
  case request.method {
    http.Get -> all(request, context)
    http.Post -> add(request, context)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn item_route(id: String, request: Request, context: Context) -> Response {
  case request.method {
    http.Patch -> update(id, request, context)
    http.Delete -> delete(id, request, context)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn all(_request: Request, context: Context) -> Response {
  let result = {
    use items <- result.try(item.get_all(context.db))
    Ok(item.all_to_json(items))
  }

  use json <- web.require_ok(result)

  wisp.json_response(json, 200)
}

fn add(request: Request, context: Context) -> Response {
  wisp.set_max_body_size(request, 500)

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

fn update(id: String, request: Request, context: Context) -> Response {
  wisp.set_max_body_size(request, 500)

  use <- wisp.require_method(request, http.Patch)
  use id <- web.require_int_param(id)
  use json <- wisp.require_json(request)

  let result = {
    use data <- result.try(
      item.decode_update_dto(json)
      |> result.replace_error(error.UnprocessableEntity),
    )
    use item <- result.try(item.update(id, data, context.db))
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
