(.registry.methods[] | select(.name == "applications.history")
  | .pagination.kind) == "opaque-cursor" and
(.registry.streams | any(.name == "applications.operation"))
