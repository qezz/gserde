import gleam/list
import gleeunit
import util

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn module_name_test() {
  let testcases = [
    #("cats.gleam", Ok("cats")),
    #("model/cats.gleam", Ok("model/cats")),
    #("./src/cats.gleam", Ok("src/cats")),
    #("../src/cats.gleam", Error(Nil)),
  ]

  testcases
  |> list.each(fn(tc) {
    assert tc.1 == util.module_name_from_rel_filepath(tc.0) as "cats"
  })
}
