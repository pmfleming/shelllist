(.registry.methods[] | select(.name == "applications.history")
  | .pagination.kind) == "opaque-cursor" and
(.registry.streams | any(.name == "applications.operation")) and
(.operation_outcome.placement_statuses == ["pending", "placed", "unavailable", "failed"]) and
(.operation_outcome.partial_success_example
  | .status == "completed" and .launch_backend == "uwsm-app" and
    .placement.status == "unavailable" and .placement.workspace_id == "3")
