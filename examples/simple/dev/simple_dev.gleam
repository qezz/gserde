import argv

import gserde

pub fn main() {
  let path = case argv.load().arguments {
    [path] -> path
    _ -> panic as "path to a directory is required as a first argument"
  }

  gserde.process_path(path)
}
