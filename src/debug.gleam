import gleam/function
import gleam/io
import gleam/list
import gleam/string

pub fn inspect(data: t, msg: String, do: Bool, f) -> t {
  case do {
    False -> data
    True -> {
      io.println(msg)
      io.println(string.inspect(f(data)))

      data
    }
  }
}

pub fn inspect_print(data: t, msg: String, do_print: Bool) -> t {
  inspect(data, msg, do_print, function.identity)
}

pub fn inspect_list(data: List(t), msg: String, do_print: Bool) -> List(t) {
  case do_print {
    False -> Nil
    True -> {
      io.println(msg)

      data |> list.each(fn(item) { io.println("  " <> string.inspect(item)) })

      Nil
    }
  }

  data
}

pub fn inspect_list_map(
  data: List(t),
  msg: String,
  do_print: Bool,
  f,
) -> List(t) {
  case do_print {
    False -> Nil
    True -> {
      io.println(msg)
      data
      |> list.map(f)
      |> list.each(fn(item) { io.println("  " <> item) })
    }
  }

  data
}
