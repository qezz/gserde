import common.{decoder_name_of_t}
import glance
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import internal/codegen/statements as gens
import internal/codegen/types as t
import internal/path.{basename}
import request.{type Request, Request}

pub type LabeledVariantFieldOnly {
  LabelledVariantFieldX(item: glance.Type, label: String)
}

fn quote(str) {
  "\"" <> str <> "\""
}

fn gen_decoder(typ, req: Request) {
  case typ {
    glance.NamedType(_loc, name, module_name, parameters) -> {
      case name {
        "List" -> {
          let assert Ok(t0) = list.first(parameters)
          gens.call("decode.list", [gen_decoder(t0, req)])
        }
        "Option" -> {
          let assert Ok(t0) = list.first(parameters)
          gens.call("decode.optional", [gen_decoder(t0, req)])
        }
        _ -> {
          case module_name {
            option.None -> {
              gens.VarPrimitive("decode." <> string.lowercase(name))
            }
            option.Some(module_str) -> {
              gens.VarPrimitive(
                module_str <> "_json." <> decoder_name_of_t(name) <> "()",
              )
            }
          }
        }
      }
    }
    x -> {
      io.println(string.inspect(#("warning: unsupported decoding", x)))
      gens.VarPrimitive("dynamic.toodoo")
    }
  }
}

fn gen_root_decoder(req: Request) {
  let Request(
    src_module_name: src_module_name,
    type_name: type_name,
    variant: variant,
    ..,
  ) = req

  let decoder_fn_name = decoder_name_of_t(type_name)

  let named_fields: List(LabeledVariantFieldOnly) =
    req.variant.fields
    |> list.map(fn(field) {
      case field {
        glance.LabelledVariantField(item:, label:) -> {
          LabelledVariantFieldX(item:, label:)
        }
        glance.UnlabelledVariantField(item: _) -> {
          let err = "Failed to process field: " <> string.inspect(field) <> "
Labeled type definitions are required for deserialization.

Wrong:
  type Foo(a, b, c) {}
    Foo(a, b, c)
  }

Correct:
  type Foo(a, b, c) {
    Foo(bar: a, baz: b, quux: c)
  }
"
          panic as err
        }
      }
    })

  let fields =
    named_fields
    |> list.map(fn(field) {
      gens.use_expr(field.label, "decode.field", [
        gens.VarPrimitive(
          field.label
          |> quote,
        ),
        gen_decoder(field.item, req),
      ])
    })

  let type_path =
    gens.named_variant_with_full_name(
      basename(src_module_name) <> "." <> variant.name,
      named_fields
        |> list.map(fn(field) { #(field.label, gens.variable(field.label)) }),
    )

  let fields_with_decode_success =
    list.append(fields, [
      gens.let_var(gens.var_pattern("parsed"), type_path),
      gens.FunctionCall("decode.success", [
        gens.VarPrimitive("parsed"),
      ]),
    ])

  [
    gens.Function(decoder_fn_name, [], fields_with_decode_success),
    gens.Function(
      "from_string",
      [gens.arg_typed("json_str", t.AnonymousType("String"))],
      [
        gens.call("json.parse", [
          gens.VarPrimitive("json_str"),
          gens.call(decoder_fn_name, []),
        ]),
      ],
    ),
  ]
}

pub fn to(req: Request) {
  gen_root_decoder(req)
  |> list.map(gens.generate)
  |> string.join(with: "\n")
}
