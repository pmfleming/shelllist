(.snapshot.data.snapshot.management.version == 1) and
(.snapshot.data.snapshot.radio.operational | type == "boolean") and
(.snapshot.data.snapshot.devices[0].policy.wait_for_services | type == "boolean") and
(.snapshot.data.snapshot.devices[0].policy.fast_pair_controls_enabled | type == "boolean") and
(.registry.methods | any(.name == "bluetooth.device.policy.update"
  and .params_schema.properties.fast_pair_controls_enabled.type == ["boolean", "null"])) and
(.audio_snapshot.data.audio_devices[0].sink.key | type == "string") and
(.registry.methods | any(.name == "bluetooth.requests.snapshot")) and
(.registry.methods | any(.name == "bluetooth.adapter.update"
  and .response_key == "adapter_batch" and .cancellable == false
  and .params_schema.properties.changes.additionalProperties == false)) and
(.adapter_update.ok == true) and
(.adapter_update.data.adapter_batch.key == "adapter-opaque") and
(.adapter_update.data.adapter_batch.outcomes | map(.state) == ["applied", "unknown", "not-attempted"]) and
(.adapter_update.data.adapter_batch.outcomes | map(.field) == ["alias", "discoverable_timeout", "pairable_timeout"]) and
(.adapter_update.data.adapter_batch.snapshot_error.message | type == "string") and
(.snapshot.data.snapshot.devices
| all(.[]; (.signal_live | type == "boolean")
    and ((.signal_strength == null) or (.signal_strength | type == "number"))
    and ((.rssi == null) or (.rssi | type == "number"))
    and (.components | type == "array")
    and ((.model_id == null) or (.model_id | type == "string"))
    and ((.last_seen_ms == null) or (.last_seen_ms | type == "number"))))
