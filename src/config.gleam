import filter

pub type Params {
  Params(
    project_root: String,
    subpaths_filter: filter.SubpathsFilter,
    generated_module_suffix: String,
  )
}
