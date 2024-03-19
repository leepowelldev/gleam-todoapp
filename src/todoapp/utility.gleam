import gleam/http.{type Method}
import gleam/list
import wisp.{type Request, type Response}

pub fn require_methods(
  request: Request,
  methods: List(Method),
  next: fn() -> Response,
) {
  case list.contains(methods, request.method) {
    True -> next()
    False -> wisp.method_not_allowed(allowed: methods)
  }
}
