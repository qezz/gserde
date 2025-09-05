import filepath
import gleam/list
import gleam/string

/// Hacky 'relative_to' function. Don't use in production.
pub fn filepath_relative_to(fullpath: String, basepath: String) -> String {
  let full = filepath.split(fullpath)
  let base = filepath.split(basepath)

  let difference = list.filter(full, fn(item) { !list.contains(base, item) })
  difference |> string.join("/")
}

pub fn module_name_from_rel_filepath(path: String) -> Result(String, Nil) {
  let expanded =
    path
    |> filepath.expand

  case expanded {
    Ok(exp) -> {
      exp
      // |> filepath.split
      // |> string.join("/")
      |> filepath.strip_extension
      |> Ok
    }
    e -> {
      // NOTE: as of (filepath v1.1.2) filepath.expand states
      // in the docs that it can return `Error("..")` but
      // the type signature says it returns `Result(String, Nil)`.
      //
      // So we can safely return the exact error here.
      e
    }
  }
}
