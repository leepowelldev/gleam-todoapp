import gleam/http.{type Method}
import gleam/list
import gleam/erlang/os
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

pub fn get_env(fallback: String) -> String {
  case os.get_env("GLEAM_ENV") {
    Ok(value) -> value
    Error(_) -> fallback
  }
}

pub fn is_dev() -> Bool {
  case os.get_env("GLEAM_ENV") {
    Ok(value) -> value == "development"
    Error(_) -> False
  }
}
