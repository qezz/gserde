import gleam/string
import justin

// NOTE: Practically speaking, if the module is called `cat_json.gleam`,
// and the usage is as `cat_json.get_decoder_cat()`, we can shorten it
// to `cat_json.decoder()` or similar.
pub fn decoder_name_of_t(raw_name: String) -> String {
  let snake_name = justin.snake_case(raw_name)
  let name = case string.ends_with(snake_name, "_json") {
    True -> string.drop_end(snake_name, 5)
    False -> snake_name
  }
  "get_decoder_" <> name
}
