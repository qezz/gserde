import gleam/option.{type Option, Some}

pub type FooJson {
  Foo(
    a_bool: Bool,
    b_int: Int,
    c_float: Float,
    e_option_int: Option(Int),
    f_string_list: List(String),
  )
}

pub fn fixture_foo() {
  Foo(
    a_bool: True,
    b_int: 1,
    c_float: 1.0,
    e_option_int: Some(4),
    f_string_list: ["a", "b"],
  )
}
