import gleam/option.{type Option}
import gleam/result
import gleam/list
import gleam/int
import gleam/bool
import gleam/string
import gleam/json.{type Json}
import gleam/dynamic.{type DecodeError, type Dynamic}
import sqlight.{type Error, type Value}
import todoapp/error.{type AppError}

pub type Item {
  Item(
    id: Int,
    content: String,
    completed: Bool,
    created_at: String,
    updated_at: String,
    completed_at: Option(String),
  )
}

pub type CreateDto {
  CreateDto(content: String)
}

pub type UpdateDto {
  UpdateDto(content: Option(String), completed: Option(Bool))
}

pub fn get_all(db: sqlight.Connection) -> Result(List(Item), AppError) {
  let sql =
    "SELECT id, content, completed, created_at, updated_at, completed_at FROM items;"

  sqlight.query(sql, on: db, with: [], expecting: decode_from_row)
  |> result.map_error(error.SqlightError)
}

pub fn get(id: String, db: sqlight.Connection) -> Result(Item, AppError) {
  let sql =
    "SELECT id, content, completed, created_at, updated_at, completed_at FROM items where id = ?1;"

  use rows <- result.try(
    sqlight.query(
      sql,
      on: db,
      with: [sqlight.text(id)],
      expecting: decode_from_row,
    )
    |> result.map_error(error.SqlightError),
  )

  case rows {
    [item] -> Ok(item)
    _ -> Error(error.Unexpected("Row not returned from query - " <> sql))
  }
}

pub fn insert(data: CreateDto, db: sqlight.Connection) -> Result(Item, AppError) {
  let sql =
    "INSERT INTO items (content) VALUES (?1) RETURNING id, content, completed, created_at, updated_at, completed_at;"

  use rows <- result.try(
    sqlight.query(
      sql,
      on: db,
      with: [sqlight.text(data.content)],
      expecting: decode_from_row,
    )
    |> result.map_error(error.SqlightError),
  )

  case rows {
    [item] -> Ok(item)
    _ -> Error(error.Unexpected("Row not returned from query - " <> sql))
  }
}

fn build_optional_query_value(
  parts: List(String),
  with: List(Value),
  index: Int,
  value value: Option(a),
  column column: String,
  with_type sqlight_type: fn(a) -> Value,
) -> #(List(String), List(Value), Int) {
  case value {
    option.Some(value) -> #(
      list.append(parts, [column <> " = ?" <> int.to_string(index)]),
      list.append(with, [sqlight_type(value)]),
      index + 1,
    )
    option.None -> #(parts, with, index)
  }
}

fn bool_to_sqlight_int(value: Bool) {
  bool.to_int(value)
  |> sqlight.int
}

pub fn update(
  id: Int,
  data: UpdateDto,
  db: sqlight.Connection,
) -> Result(Item, AppError) {
  let index = 2
  let with = [sqlight.int(id)]
  let parts: List(String) = []

  let #(parts, with, index) =
    build_optional_query_value(
      parts,
      with,
      index,
      value: data.content,
      column: "content",
      with_type: sqlight.text,
    )
  let #(parts, with, _) =
    build_optional_query_value(
      parts,
      with,
      index,
      value: data.completed,
      column: "completed",
      with_type: bool_to_sqlight_int,
    )

  // If no content and no completed data is sent parts will be empty and will create an invalid SQL query
  case parts {
    [] -> Error(error.UnprocessableEntity)
    _ -> Ok(Nil)
  }
  |> result.try(fn(_) {
    let sql =
      "UPDATE items SET "
      <> string.join(parts, ", ")
      <> " WHERE id = ?1 returning id, content, completed, created_at, updated_at, completed_at;"

    use rows <- result.try(
      sqlight.query(sql, on: db, with: with, expecting: decode_from_row)
      |> result.map_error(error.SqlightError),
    )

    case rows {
      [item] -> Ok(item)
      [] -> Error(error.NotFound)
      _ -> Error(error.Unexpected("Row not returned from query - " <> sql))
    }
  })
}

pub fn delete(id: Int, db: sqlight.Connection) -> Result(Item, AppError) {
  let sql =
    "DELETE FROM items WHERE id = ?1 returning id, content, completed, created_at, updated_at, completed_at;"

  use rows <- result.try(
    sqlight.query(
      sql,
      on: db,
      with: [sqlight.int(id)],
      expecting: decode_from_row,
    )
    |> result.map_error(error.SqlightError),
  )

  case rows {
    [item] -> Ok(item)
    [] -> Error(error.NotFound)
    _ -> Error(error.Unexpected("Row not returned from query - " <> sql))
  }
}

pub fn encode_all(items: List(Item)) -> Json {
  json.array(items, encode)
}

pub fn encode(item: Item) -> Json {
  json.object([
    #("id", json.int(item.id)),
    #("content", json.string(item.content)),
    #("completed", json.bool(item.completed)),
    #("created_at", json.string(item.created_at)),
    #("updated_at", json.string(item.updated_at)),
    #("completed_at", json.nullable(item.completed_at, json.string)),
  ])
}

pub fn decode_from_row(data: Dynamic) -> Result(Item, List(DecodeError)) {
  dynamic.decode6(
    Item,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
    dynamic.element(2, sqlight.decode_bool),
    dynamic.element(3, dynamic.string),
    dynamic.element(4, dynamic.string),
    dynamic.element(5, dynamic.optional(dynamic.string)),
  )(data)
}

pub fn decode_create_dto(data: Dynamic) -> Result(CreateDto, List(DecodeError)) {
  dynamic.decode1(CreateDto, dynamic.field("content", decode_content))(data)
}

pub fn decode_update_dto(data: Dynamic) -> Result(UpdateDto, List(DecodeError)) {
  dynamic.decode2(
    UpdateDto,
    dynamic.optional_field("content", decode_content),
    dynamic.optional_field("completed", dynamic.bool),
  )(data)
}

fn decode_content(data: Dynamic) -> Result(String, List(DecodeError)) {
  dynamic.string(data)
  |> result.try(fn(data) {
    let length = string.length(data)
    case length > 1 && length <= 50 {
      True -> Ok(data)
      False ->
        Error([
          dynamic.DecodeError(
            "Length to be between 1 and 50 characters",
            int.to_string(length),
            [],
          ),
        ])
    }
  })
}

pub fn to_json(item: Item) {
  let json = encode(item)
  json.to_string_builder(json)
}

pub fn all_to_json(items: List(Item)) {
  let json = encode_all(items)
  json.to_string_builder(json)
}
