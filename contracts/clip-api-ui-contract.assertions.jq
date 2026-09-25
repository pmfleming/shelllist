(.registry.methods | any(.name == "clipboard.capture.setPaused")) and
(.registry.methods | any(.name == "clipboard.selection.publishFiles")) and
(.registry.methods | any(.name == "clipboard.entries.delete")) and
((.registry.streams[] | select(.name == "clipboard.operation")
  | .events | index("progress")) != null)
