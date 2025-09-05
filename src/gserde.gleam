import config
import debug
import evil.{expect}
import filepath
import filter
import fswalk
import glance
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/yielder
import internal/deserializer
import internal/serializer
import request.{type Request, Request}
import simplifile
import util

pub fn gen(req: Request) {
  let ser =
    bool.guard(when: req.ser, return: serializer.from(req), otherwise: fn() {
      ""
    })
  let de =
    bool.guard(when: req.de, return: deserializer.to(req), otherwise: fn() {
      ""
    })

  #(
    req,
    [ser, de]
      |> string.join("\n\n"),
  )
}

fn to_output_filename(src_filename) {
  string.replace(in: src_filename, each: ".gleam", with: "_json.gleam")
}

pub fn main() {
  let params =
    config.Params(
      project_root: "testproject",
      subpaths_filter: filter.Dirs(["src"]),
      generated_module_suffix: "_json",
    )

  let outputs = process(params, True)

  outputs
  |> list.each(fn(gf) { simplifile.write(gf.filepath, gf.data) })
}

pub type ParsedFileResult {
  ParsedFileResult(
    filepath: String,
    module_name: String,
    mod: Result(glance.Module, glance.Error),
  )
}

// For now only supports files from <project_root>/src/...
pub type CustomFilePath {
  SrcFilePath(project_root: String, rel_filepath: String, full_path: String)
}

pub type ParsedFile {
  ParsedFile(filepath: String, module_name: String, mod: glance.Module)
}

pub type GeneratedFile {
  GeneratedFile(filepath: String, module_name: String, data: String)
}

fn find_gleam_files(root: String) -> List(CustomFilePath) {
  fswalk.builder()
  |> fswalk.with_path(root)
  // |> fswalk.with_traversal_filter(fn(it) {
  //   string.ends_with(it.filename, ".gleam") && !it.stat.is_directory
  // })
  |> fswalk.walk
  |> yielder.map(fn(v) { expect(v, "failed to walk").filename })
  |> yielder.filter(fn(v) {
    // I have no idea why the traversal filter still includes directories.
    string.ends_with(v, ".gleam")
  })
  |> yielder.map(fn(fp) {
    SrcFilePath(
      project_root: root,
      rel_filepath: util.filepath_relative_to(fp, root),
      full_path: fp,
    )
  })
  |> yielder.to_list
}

pub fn process(params: config.Params, verbose: Bool) -> List(GeneratedFile) {
  debug.inspect_print(params, "Parameters:", verbose)

  let files = case params.subpaths_filter {
    filter.All -> find_gleam_files(params.project_root)
    filter.Dirs(dirs) -> {
      dirs
      |> list.flat_map(fn(dir) {
        find_gleam_files(filepath.join(params.project_root, dir))
      })
    }
  }

  files
  |> debug.inspect_list_map("Filtered files:", verbose, fn(item) {
    item.rel_filepath
  })
  |> list.map(fn(cfp) {
    ParsedFileResult(
      filepath: cfp.full_path,
      module_name: result.unwrap(
        util.module_name_from_rel_filepath(cfp.rel_filepath),
        "can't derive module name",
      ),
      mod: parse_file(cfp.full_path),
    )
  })
  // TODO: filter out files based on TypeFilter
  |> debug.inspect_list_map("Parsed:", verbose, fn(item) {
    #(item.filepath, result.map(item.mod, fn(_) { Nil })) |> string.inspect
  })
  |> list.map(fn(parsed) {
    let assert Ok(m) = parsed.mod
    ParsedFile(parsed.filepath, parsed.module_name, m)
  })
  |> list.map(process_single)
  |> list.filter_map(fn(maybe) { option.to_result(maybe, Nil) })
  |> debug.inspect_list_map("Processed:", verbose, fn(item: GeneratedFile) {
    item.filepath
  })
}

pub fn parse_file(filepath: String) -> Result(glance.Module, glance.Error) {
  let assert Ok(source) = simplifile.read(from: filepath)

  source |> glance.module()
}

pub fn process_single(p: ParsedFile) -> option.Option(GeneratedFile) {
  io.println("Processing: " <> p.filepath)

  let src_module_name = p.module_name

  let dest_filename = to_output_filename(p.filepath)

  // TODO: properly filter the custom types
  let custom_types = list.map(p.mod.custom_types, fn(def) { def.definition })

  // NOTE: It should be possible to allow multiple generated types per file,
  // but in that case the names of the generated modules and functions
  // should be carefully crafted.
  bool.guard(
    when: list.length(of: custom_types) <= 1,
    return: Nil,
    otherwise: fn() { panic as "Only one json type is allowed per file" },
  )

  let requests =
    custom_types
    |> debug.inspect_list_map(
      "Types: (" <> int.to_string(list.length(custom_types)) <> ")",
      True,
      fn(item) { item.name },
    )
    |> list.flat_map(fn(custom_type) {
      list.map(custom_type.variants, fn(variant) {
        Request(
          src_module_name: src_module_name,
          type_name: custom_type.name,
          module: p.mod,
          variant: variant,
          ser: True,
          de: True,
        )
      })
    })

  let filecontent =
    list.map(requests, gen)
    |> list.map(fn(it) { it.1 })
    |> string.join("\n\n")

  case filecontent {
    "" -> option.None
    other -> {
      let content2 =
        [
          "import gleam/json",
          "import gleam/dynamic/decode",
          "import " <> p.module_name,
          other,
        ]
        |> string.join("\n")

      option.Some(GeneratedFile(
        filepath: dest_filename,
        module_name: p.module_name,
        data: content2,
      ))
    }
  }
}
