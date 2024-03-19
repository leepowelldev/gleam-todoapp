import gleam/option.{type Option}
import gleam/result
import gleam/list
import gleam/io
import gleam/json.{type Json}
import gleam/dynamic.{type DecodeError, type Dynamic}
import todoapp/error.{type AppError}
import sqlight

pub type Item {
  Item(
    id: Int,
    content: String,
    completed: Bool,
    created_at: String,
    updated_at: String,
  )
}

pub type CreateItemDto {
  CreateItemDto(content: String)
}

pub type UpdateItemDto {
  UpdateItemDto(content: Option(String), completed: Option(Bool))
}

pub fn get_items(db: sqlight.Connection) -> Result(List(Item), AppError) {
  let sql = "select id, content, completed, created_at, updated_at from items;"

  sqlight.query(sql, on: db, with: [], expecting: decode_item_row)
  |> result.map_error(fn(error) {
    io.debug(error)
    error.SqlightError(error)
  })
}

pub fn insert_item(
  data: CreateItemDto,
  db: sqlight.Connection,
) -> Result(Item, AppError) {
  let sql =
    "insert into items (content) values (?1) returning id, content, completed, created_at, updated_at;"

  use rows <- result.then(
    sqlight.query(
      sql,
      on: db,
      with: [sqlight.text(data.content)],
      expecting: decode_item_row,
    )
    |> result.map_error(fn(error) {
      io.debug(error)
      error.SqlightError(error)
    }),
  )

  case list.first(rows) {
    Ok(item) -> Ok(item)
    Error(_) -> Error(error.Unexpected)
  }
}

pub fn encode_items(items: List(Item)) -> Json {
  json.array(items, encode_item)
}

pub fn encode_item(item: Item) -> Json {
  json.object([
    #("id", json.int(item.id)),
    #("content", json.string(item.content)),
    #("completed", json.bool(item.completed)),
    #("created_at", json.string(item.created_at)),
    #("updated_at", json.string(item.updated_at)),
  ])
}

pub fn decode_item_row(data: Dynamic) -> Result(Item, List(DecodeError)) {
  dynamic.decode5(
    Item,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
    dynamic.element(2, sqlight.decode_bool),
    dynamic.element(3, dynamic.string),
    dynamic.element(4, dynamic.string),
  )(data)
}

pub fn decode_create_item_dto(
  data: Dynamic,
) -> Result(CreateItemDto, List(DecodeError)) {
  dynamic.decode1(CreateItemDto, dynamic.field("content", dynamic.string))(data)
}
