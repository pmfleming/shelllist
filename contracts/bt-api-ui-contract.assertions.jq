(.snapshot.data.snapshot.management.version == 1) and
(.snapshot.data.snapshot.radio.operational | type == "boolean") and
(.snapshot.data.snapshot.devices[0].policy.wait_for_services | type == "boolean") and
(.snapshot.data.snapshot.devices[0].policy.fast_pair_controls_enabled | type == "boolean") and
(.registry.methods | any(.name == "bluetooth.device.policy.update"
  and .params_schema.properties.fast_pair_controls_enabled.type == ["boolean", "null"])) and
(.audio_snapshot.data.audio_devices[0].sink.key | type == "string") and
(.registry.methods | any(.name == "bluetooth.requests.snapshot")) and
(.snapshot.data.snapshot.devices
| all(.[]; (.signal_live | type == "boolean")
    and ((.signal_strength == null) or (.signal_strength | type == "number"))
    and ((.rssi == null) or (.rssi | type == "number"))
    and (.components | type == "array")
    and ((.model_id == null) or (.model_id | type == "string"))
    and ((.last_seen_ms == null) or (.last_seen_ms | type == "number"))))
