.pragma library

// Generated from the daemon-owned protocol registry. Do not edit.
var protocol = "bar-api";
var version = 2;
var methods = ({
    "bar.snapshot": "bar.snapshot",
    "activity.queryRange": "activity.queryRange",
    "activity.refresh": "activity.refresh",
    "locations.search": "locations.search",
    "locations.add": "locations.add",
    "locations.remove": "locations.remove",
    "location.status": "location.status",
    "location.setManual": "location.setManual",
    "location.returnToAutomatic": "location.returnToAutomatic",
    "todos.create": "todos.create",
    "todos.complete": "todos.complete",
    "todos.delete": "todos.delete",
    "workspace.focus": "workspace.focus",
    "media.operation": "media.operation",
    "audio.adjust": "audio.adjust",
    "audio.setMuted": "audio.setMuted",
    "audio.setInputMuted": "audio.setInputMuted",
    "brightness.adjust": "brightness.adjust",
    "brightness.set": "brightness.set",
    "battery.history": "battery.history",
    "battery.operation.start": "battery.operation.start",
    "battery.operation.status": "battery.operation.status",
    "battery.operation.cancel": "battery.operation.cancel",
    "battery.setThresholds": "battery.setThresholds",
    "battery.setProtection": "battery.setProtection",
    "battery.chargeOnce": "battery.chargeOnce",
    "battery.setChargingInhibited": "battery.setChargingInhibited",
    "battery.startCalibration": "battery.startCalibration",
    "battery.cancelCalibration": "battery.cancelCalibration",
    "battery.setAlertPolicy": "battery.setAlertPolicy",
    "powerProfile.set": "powerProfile.set",
    "powerProfile.resumeAutomatic": "powerProfile.resumeAutomatic",
    "powerProfile.setBatteryAware": "powerProfile.setBatteryAware",
    "powerProfile.setActionEnabled": "powerProfile.setActionEnabled",
    "powerSleep.lock": "powerSleep.lock",
    "powerSleep.suspend": "powerSleep.suspend",
    "powerSleep.hibernate": "powerSleep.hibernate",
    "powerSleep.setKeepAwake": "powerSleep.setKeepAwake",
    "powerSleep.setPolicy": "powerSleep.setPolicy",
    "powerSleep.idle": "powerSleep.idle",
    "powerSleep.cancelCritical": "powerSleep.cancelCritical",
    "powerSleep.setCriticalPolicy": "powerSleep.setCriticalPolicy",
    "displayPolicy.set": "displayPolicy.set",
    "displayFocus.set": "displayFocus.set",
    "displayFocus.reset": "displayFocus.reset",
    "displayLayout.preview": "displayLayout.preview",
    "displayLayout.confirm": "displayLayout.confirm",
    "displayLayout.revert": "displayLayout.revert",
    "notifications.togglePanel": "notifications.togglePanel",
    "notifications.toggleDnd": "notifications.toggleDnd",
    "notifications.setDnd": "notifications.setDnd",
    "notifications.setAppPolicy": "notifications.setAppPolicy",
    "notifications.prepareDelete": "notifications.prepareDelete",
    "notifications.delete": "notifications.delete",
    "notifications.list": "notifications.list",
    "notifications.queryCenter": "notifications.queryCenter",
    "notifications.queryHistory": "notifications.queryHistory",
    "notifications.dismiss": "notifications.dismiss",
    "notifications.clear": "notifications.clear",
    "notifications.clearGroup": "notifications.clearGroup",
    "notifications.snooze": "notifications.snooze",
    "notifications.invokeAction": "notifications.invokeAction",
    "notifications.reply": "notifications.reply",
    "updates.refresh": "updates.refresh",
});
var streams = ({
    "activity.changed": "activity.changed",
    "workspaces.changed": "workspaces.changed",
    "workarea.changed": "workarea.changed",
    "compositor.changed": "compositor.changed",
    "media.changed": "media.changed",
    "audio.changed": "audio.changed",
    "brightness.changed": "brightness.changed",
    "battery.changed": "battery.changed",
    "power-profile.changed": "power-profile.changed",
    "power-sleep.changed": "power-sleep.changed",
    "sleep-policy.changed": "sleep-policy.changed",
    "display-policy.changed": "display-policy.changed",
    "osd-hardware.changed": "osd-hardware.changed",
    "notifications.changed": "notifications.changed",
    "notifications.active.changed": "notifications.active.changed",
    "updates.changed": "updates.changed",
    "timezone.changed": "timezone.changed",
});

var contracts = {"audio.adjust":{"params_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"delta_percent":{"format":"int16","maximum":32767,"minimum":-32768,"type":"integer"}},"required":["delta_percent"],"title":"DeltaRequest","type":"object"},"policy":{"ack_budget_ms":30000,"conflict_domain":"audio","execution":"effect","max_in_flight":16,"max_owner_in_flight":8,"request_bytes":1048576,"result_bytes":16777216,"sensitivity":"effect"},"response_key":"audio","result_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"available":{"type":"boolean"},"error":{"type":["string","null"]},"input_available":{"type":"boolean"},"input_muted":{"type":"boolean"},"muted":{"type":"boolean"},"sink_description":{"type":"string"},"sink_name":{"type":"string"},"source_description":{"type":"string"},"source_name":{"type":"string"},"volume_percent":{"format":"uint8","maximum":255,"minimum":0,"type":"integer"}},"required":["available","sink_name","sink_description","volume_percent","muted","input_available","source_name","source_description","input_muted","error"],"title":"AudioState","type":"object"}},"audio.setInputMuted":{"params_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"muted":{"default":null,"type":["boolean","null"]}},"title":"MuteRequest","type":"object"},"policy":{"ack_budget_ms":30000,"conflict_domain":"audio","execution":"effect","max_in_flight":16,"max_owner_in_flight":8,"request_bytes":1048576,"result_bytes":16777216,"sensitivity":"effect"},"response_key":"audio","result_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"available":{"type":"boolean"},"error":{"type":["string","null"]},"input_available":{"type":"boolean"},"input_muted":{"type":"boolean"},"muted":{"type":"boolean"},"sink_description":{"type":"string"},"sink_name":{"type":"string"},"source_description":{"type":"string"},"source_name":{"type":"string"},"volume_percent":{"format":"uint8","maximum":255,"minimum":0,"type":"integer"}},"required":["available","sink_name","sink_description","volume_percent","muted","input_available","source_name","source_description","input_muted","error"],"title":"AudioState","type":"object"}},"audio.setMuted":{"params_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"muted":{"default":null,"type":["boolean","null"]}},"title":"MuteRequest","type":"object"},"policy":{"ack_budget_ms":30000,"conflict_domain":"audio","execution":"effect","max_in_flight":16,"max_owner_in_flight":8,"request_bytes":1048576,"result_bytes":16777216,"sensitivity":"effect"},"response_key":"audio","result_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"available":{"type":"boolean"},"error":{"type":["string","null"]},"input_available":{"type":"boolean"},"input_muted":{"type":"boolean"},"muted":{"type":"boolean"},"sink_description":{"type":"string"},"sink_name":{"type":"string"},"source_description":{"type":"string"},"source_name":{"type":"string"},"volume_percent":{"format":"uint8","maximum":255,"minimum":0,"type":"integer"}},"required":["available","sink_name","sink_description","volume_percent","muted","input_available","source_name","source_description","input_muted","error"],"title":"AudioState","type":"object"}},"brightness.adjust":{"params_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"delta_percent":{"format":"int16","maximum":32767,"minimum":-32768,"type":"integer"}},"required":["delta_percent"],"title":"DeltaRequest","type":"object"},"policy":{"ack_budget_ms":30000,"conflict_domain":"brightness","execution":"effect","max_in_flight":16,"max_owner_in_flight":8,"request_bytes":1048576,"result_bytes":16777216,"sensitivity":"effect"},"response_key":"brightness","result_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"available":{"type":"boolean"},"brightness":{"format":"uint64","minimum":0,"type":"integer"},"device":{"type":"string"},"error":{"type":["string","null"]},"max_brightness":{"format":"uint64","minimum":0,"type":"integer"},"percent":{"format":"uint8","maximum":255,"minimum":0,"type":"integer"}},"required":["available","device","brightness","max_brightness","percent","error"],"title":"BrightnessState","type":"object"}},"brightness.set":{"params_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"percent":{"format":"uint8","maximum":255,"minimum":0,"type":"integer"}},"required":["percent"],"title":"PercentRequest","type":"object"},"policy":{"ack_budget_ms":30000,"conflict_domain":"brightness","execution":"effect","max_in_flight":16,"max_owner_in_flight":8,"request_bytes":1048576,"result_bytes":16777216,"sensitivity":"effect"},"response_key":"brightness","result_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"available":{"type":"boolean"},"brightness":{"format":"uint64","minimum":0,"type":"integer"},"device":{"type":"string"},"error":{"type":["string","null"]},"max_brightness":{"format":"uint64","minimum":0,"type":"integer"},"percent":{"format":"uint8","maximum":255,"minimum":0,"type":"integer"}},"required":["available","device","brightness","max_brightness","percent","error"],"title":"BrightnessState","type":"object"}},"powerProfile.resumeAutomatic":{"params_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","title":"AnyValue"},"policy":{"ack_budget_ms":30000,"conflict_domain":"power-profile","execution":"effect","max_in_flight":16,"max_owner_in_flight":8,"request_bytes":1048576,"result_bytes":16777216,"sensitivity":"effect"},"response_key":"power_profile","result_schema":{"$defs":{"BatteryAutomationState":{"properties":{"error":{"default":null,"type":["string","null"]},"level":{"default":"","type":"string"},"profile":{"default":"","type":"string"},"status":{"default":"","type":"string"}},"required":["level","status","profile","error"],"type":"object"},"PowerProfile":{"properties":{"driver":{"type":"string"},"name":{"type":"string"},"platform_driver":{"type":"string"}},"required":["name","driver","platform_driver"],"type":"object"},"PowerProfileAction":{"properties":{"description":{"type":"string"},"enabled":{"type":"boolean"},"name":{"type":"string"}},"required":["name","description","enabled"],"type":"object"},"PowerProfileHold":{"properties":{"application_id":{"type":"string"},"profile":{"type":"string"},"reason":{"type":"string"}},"required":["application_id","profile","reason"],"type":"object"}},"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"actions":{"items":{"$ref":"#/$defs/PowerProfileAction"},"type":"array"},"active_holds":{"items":{"$ref":"#/$defs/PowerProfileHold"},"type":"array"},"available":{"type":"boolean"},"battery_automation":{"$ref":"#/$defs/BatteryAutomationState","default":{"error":null,"level":"","profile":"","status":""}},"battery_aware":{"type":["boolean","null"]},"driver":{"type":"string"},"error":{"type":["string","null"]},"performance_degraded":{"type":"string"},"profile":{"type":"string"},"profiles":{"items":{"$ref":"#/$defs/PowerProfile"},"type":"array"},"version":{"type":"string"}},"required":["available","profile","driver","profiles","performance_degraded","version","battery_aware","actions","active_holds","battery_automation","error"],"title":"PowerProfileState","type":"object"}},"powerProfile.set":{"params_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"profile":{"type":"string"}},"required":["profile"],"title":"ProfileRequest","type":"object"},"policy":{"ack_budget_ms":30000,"conflict_domain":"power-profile","execution":"effect","max_in_flight":16,"max_owner_in_flight":8,"request_bytes":1048576,"result_bytes":16777216,"sensitivity":"effect"},"response_key":"power_profile","result_schema":{"$defs":{"BatteryAutomationState":{"properties":{"error":{"default":null,"type":["string","null"]},"level":{"default":"","type":"string"},"profile":{"default":"","type":"string"},"status":{"default":"","type":"string"}},"required":["level","status","profile","error"],"type":"object"},"PowerProfile":{"properties":{"driver":{"type":"string"},"name":{"type":"string"},"platform_driver":{"type":"string"}},"required":["name","driver","platform_driver"],"type":"object"},"PowerProfileAction":{"properties":{"description":{"type":"string"},"enabled":{"type":"boolean"},"name":{"type":"string"}},"required":["name","description","enabled"],"type":"object"},"PowerProfileHold":{"properties":{"application_id":{"type":"string"},"profile":{"type":"string"},"reason":{"type":"string"}},"required":["application_id","profile","reason"],"type":"object"}},"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"actions":{"items":{"$ref":"#/$defs/PowerProfileAction"},"type":"array"},"active_holds":{"items":{"$ref":"#/$defs/PowerProfileHold"},"type":"array"},"available":{"type":"boolean"},"battery_automation":{"$ref":"#/$defs/BatteryAutomationState","default":{"error":null,"level":"","profile":"","status":""}},"battery_aware":{"type":["boolean","null"]},"driver":{"type":"string"},"error":{"type":["string","null"]},"performance_degraded":{"type":"string"},"profile":{"type":"string"},"profiles":{"items":{"$ref":"#/$defs/PowerProfile"},"type":"array"},"version":{"type":"string"}},"required":["available","profile","driver","profiles","performance_degraded","version","battery_aware","actions","active_holds","battery_automation","error"],"title":"PowerProfileState","type":"object"}},"powerProfile.setActionEnabled":{"params_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"action":{"type":"string"},"enabled":{"type":"boolean"}},"required":["action","enabled"],"title":"ProfileActionRequest","type":"object"},"policy":{"ack_budget_ms":30000,"conflict_domain":"power-profile","execution":"effect","max_in_flight":16,"max_owner_in_flight":8,"request_bytes":1048576,"result_bytes":16777216,"sensitivity":"effect"},"response_key":"power_profile","result_schema":{"$defs":{"BatteryAutomationState":{"properties":{"error":{"default":null,"type":["string","null"]},"level":{"default":"","type":"string"},"profile":{"default":"","type":"string"},"status":{"default":"","type":"string"}},"required":["level","status","profile","error"],"type":"object"},"PowerProfile":{"properties":{"driver":{"type":"string"},"name":{"type":"string"},"platform_driver":{"type":"string"}},"required":["name","driver","platform_driver"],"type":"object"},"PowerProfileAction":{"properties":{"description":{"type":"string"},"enabled":{"type":"boolean"},"name":{"type":"string"}},"required":["name","description","enabled"],"type":"object"},"PowerProfileHold":{"properties":{"application_id":{"type":"string"},"profile":{"type":"string"},"reason":{"type":"string"}},"required":["application_id","profile","reason"],"type":"object"}},"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"actions":{"items":{"$ref":"#/$defs/PowerProfileAction"},"type":"array"},"active_holds":{"items":{"$ref":"#/$defs/PowerProfileHold"},"type":"array"},"available":{"type":"boolean"},"battery_automation":{"$ref":"#/$defs/BatteryAutomationState","default":{"error":null,"level":"","profile":"","status":""}},"battery_aware":{"type":["boolean","null"]},"driver":{"type":"string"},"error":{"type":["string","null"]},"performance_degraded":{"type":"string"},"profile":{"type":"string"},"profiles":{"items":{"$ref":"#/$defs/PowerProfile"},"type":"array"},"version":{"type":"string"}},"required":["available","profile","driver","profiles","performance_degraded","version","battery_aware","actions","active_holds","battery_automation","error"],"title":"PowerProfileState","type":"object"}},"powerProfile.setBatteryAware":{"params_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"enabled":{"type":"boolean"}},"required":["enabled"],"title":"EnabledRequest","type":"object"},"policy":{"ack_budget_ms":30000,"conflict_domain":"power-profile","execution":"effect","max_in_flight":16,"max_owner_in_flight":8,"request_bytes":1048576,"result_bytes":16777216,"sensitivity":"effect"},"response_key":"power_profile","result_schema":{"$defs":{"BatteryAutomationState":{"properties":{"error":{"default":null,"type":["string","null"]},"level":{"default":"","type":"string"},"profile":{"default":"","type":"string"},"status":{"default":"","type":"string"}},"required":["level","status","profile","error"],"type":"object"},"PowerProfile":{"properties":{"driver":{"type":"string"},"name":{"type":"string"},"platform_driver":{"type":"string"}},"required":["name","driver","platform_driver"],"type":"object"},"PowerProfileAction":{"properties":{"description":{"type":"string"},"enabled":{"type":"boolean"},"name":{"type":"string"}},"required":["name","description","enabled"],"type":"object"},"PowerProfileHold":{"properties":{"application_id":{"type":"string"},"profile":{"type":"string"},"reason":{"type":"string"}},"required":["application_id","profile","reason"],"type":"object"}},"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"actions":{"items":{"$ref":"#/$defs/PowerProfileAction"},"type":"array"},"active_holds":{"items":{"$ref":"#/$defs/PowerProfileHold"},"type":"array"},"available":{"type":"boolean"},"battery_automation":{"$ref":"#/$defs/BatteryAutomationState","default":{"error":null,"level":"","profile":"","status":""}},"battery_aware":{"type":["boolean","null"]},"driver":{"type":"string"},"error":{"type":["string","null"]},"performance_degraded":{"type":"string"},"profile":{"type":"string"},"profiles":{"items":{"$ref":"#/$defs/PowerProfile"},"type":"array"},"version":{"type":"string"}},"required":["available","profile","driver","profiles","performance_degraded","version","battery_aware","actions","active_holds","battery_automation","error"],"title":"PowerProfileState","type":"object"}}};
var eventContracts = {"audio.changed:changed":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"available":{"type":"boolean"},"error":{"type":["string","null"]},"input_available":{"type":"boolean"},"input_muted":{"type":"boolean"},"muted":{"type":"boolean"},"sink_description":{"type":"string"},"sink_name":{"type":"string"},"source_description":{"type":"string"},"source_name":{"type":"string"},"volume_percent":{"format":"uint8","maximum":255,"minimum":0,"type":"integer"}},"required":["available","sink_name","sink_description","volume_percent","muted","input_available","source_name","source_description","input_muted","error"],"title":"AudioState","type":"object"},"audio.changed:gap":{"$defs":{"GapReason":{"enum":["subscriber-lag","source-reset"],"type":"string"}},"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"dropped_events":{"description":"Decimal string: loss counters must survive JavaScript without rounding.","type":"string"},"reason":{"$ref":"#/$defs/GapReason"}},"required":["reason","dropped_events"],"title":"Gap","type":"object"},"audio.changed:subscribed":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"available":{"type":"boolean"},"error":{"type":["string","null"]},"input_available":{"type":"boolean"},"input_muted":{"type":"boolean"},"muted":{"type":"boolean"},"sink_description":{"type":"string"},"sink_name":{"type":"string"},"source_description":{"type":"string"},"source_name":{"type":"string"},"volume_percent":{"format":"uint8","maximum":255,"minimum":0,"type":"integer"}},"required":["available","sink_name","sink_description","volume_percent","muted","input_available","source_name","source_description","input_muted","error"],"title":"AudioState","type":"object"},"brightness.changed:changed":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"available":{"type":"boolean"},"brightness":{"format":"uint64","minimum":0,"type":"integer"},"device":{"type":"string"},"error":{"type":["string","null"]},"max_brightness":{"format":"uint64","minimum":0,"type":"integer"},"percent":{"format":"uint8","maximum":255,"minimum":0,"type":"integer"}},"required":["available","device","brightness","max_brightness","percent","error"],"title":"BrightnessState","type":"object"},"brightness.changed:gap":{"$defs":{"GapReason":{"enum":["subscriber-lag","source-reset"],"type":"string"}},"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"dropped_events":{"description":"Decimal string: loss counters must survive JavaScript without rounding.","type":"string"},"reason":{"$ref":"#/$defs/GapReason"}},"required":["reason","dropped_events"],"title":"Gap","type":"object"},"brightness.changed:subscribed":{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"available":{"type":"boolean"},"brightness":{"format":"uint64","minimum":0,"type":"integer"},"device":{"type":"string"},"error":{"type":["string","null"]},"max_brightness":{"format":"uint64","minimum":0,"type":"integer"},"percent":{"format":"uint8","maximum":255,"minimum":0,"type":"integer"}},"required":["available","device","brightness","max_brightness","percent","error"],"title":"BrightnessState","type":"object"},"power-profile.changed:changed":{"$defs":{"BatteryAutomationState":{"properties":{"error":{"default":null,"type":["string","null"]},"level":{"default":"","type":"string"},"profile":{"default":"","type":"string"},"status":{"default":"","type":"string"}},"required":["level","status","profile","error"],"type":"object"},"PowerProfile":{"properties":{"driver":{"type":"string"},"name":{"type":"string"},"platform_driver":{"type":"string"}},"required":["name","driver","platform_driver"],"type":"object"},"PowerProfileAction":{"properties":{"description":{"type":"string"},"enabled":{"type":"boolean"},"name":{"type":"string"}},"required":["name","description","enabled"],"type":"object"},"PowerProfileHold":{"properties":{"application_id":{"type":"string"},"profile":{"type":"string"},"reason":{"type":"string"}},"required":["application_id","profile","reason"],"type":"object"}},"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"actions":{"items":{"$ref":"#/$defs/PowerProfileAction"},"type":"array"},"active_holds":{"items":{"$ref":"#/$defs/PowerProfileHold"},"type":"array"},"available":{"type":"boolean"},"battery_automation":{"$ref":"#/$defs/BatteryAutomationState","default":{"error":null,"level":"","profile":"","status":""}},"battery_aware":{"type":["boolean","null"]},"driver":{"type":"string"},"error":{"type":["string","null"]},"performance_degraded":{"type":"string"},"profile":{"type":"string"},"profiles":{"items":{"$ref":"#/$defs/PowerProfile"},"type":"array"},"version":{"type":"string"}},"required":["available","profile","driver","profiles","performance_degraded","version","battery_aware","actions","active_holds","battery_automation","error"],"title":"PowerProfileState","type":"object"},"power-profile.changed:gap":{"$defs":{"GapReason":{"enum":["subscriber-lag","source-reset"],"type":"string"}},"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"dropped_events":{"description":"Decimal string: loss counters must survive JavaScript without rounding.","type":"string"},"reason":{"$ref":"#/$defs/GapReason"}},"required":["reason","dropped_events"],"title":"Gap","type":"object"},"power-profile.changed:subscribed":{"$defs":{"BatteryAutomationState":{"properties":{"error":{"default":null,"type":["string","null"]},"level":{"default":"","type":"string"},"profile":{"default":"","type":"string"},"status":{"default":"","type":"string"}},"required":["level","status","profile","error"],"type":"object"},"PowerProfile":{"properties":{"driver":{"type":"string"},"name":{"type":"string"},"platform_driver":{"type":"string"}},"required":["name","driver","platform_driver"],"type":"object"},"PowerProfileAction":{"properties":{"description":{"type":"string"},"enabled":{"type":"boolean"},"name":{"type":"string"}},"required":["name","description","enabled"],"type":"object"},"PowerProfileHold":{"properties":{"application_id":{"type":"string"},"profile":{"type":"string"},"reason":{"type":"string"}},"required":["application_id","profile","reason"],"type":"object"}},"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"actions":{"items":{"$ref":"#/$defs/PowerProfileAction"},"type":"array"},"active_holds":{"items":{"$ref":"#/$defs/PowerProfileHold"},"type":"array"},"available":{"type":"boolean"},"battery_automation":{"$ref":"#/$defs/BatteryAutomationState","default":{"error":null,"level":"","profile":"","status":""}},"battery_aware":{"type":["boolean","null"]},"driver":{"type":"string"},"error":{"type":["string","null"]},"performance_degraded":{"type":"string"},"profile":{"type":"string"},"profiles":{"items":{"$ref":"#/$defs/PowerProfile"},"type":"array"},"version":{"type":"string"}},"required":["available","profile","driver","profiles","performance_degraded","version","battery_aware","actions","active_holds","battery_automation","error"],"title":"PowerProfileState","type":"object"}};
// Runtime validation for the generated JSON Schema subset. No QML objects or eval.
function schemaError(schema, value, root, path) {
    root = root || schema;
    path = path || "$";
    if (schema === true) return "";
    if (schema === false) return path + " is forbidden";
    if (schema.$ref) {
        if (schema.$ref.indexOf("#/") !== 0) return path + " has an unsupported schema reference";
        var target = root;
        var parts = schema.$ref.slice(2).split("/");
        for (var r = 0; r < parts.length; r++) {
            target = target && target[parts[r].replace(/~1/g, "/").replace(/~0/g, "~")];
        }
        if (target === undefined) return path + " has an unresolved schema reference";
        var referenceError = schemaError(target, value, root, path);
        if (referenceError) return referenceError;
    }
    if (schema.const !== undefined && JSON.stringify(value) !== JSON.stringify(schema.const)) return path + " differs from constant";
    if (schema.enum && !schema.enum.some(function (item) { return JSON.stringify(item) === JSON.stringify(value); })) return path + " is not a registered value";
    for (var group of ["allOf", "anyOf", "oneOf"]) {
        if (!schema[group]) continue;
        var matches = schema[group].filter(function (part) { return !schemaError(part, value, root, path); }).length;
        if ((group === "allOf" && matches !== schema[group].length) || (group === "anyOf" && matches === 0) || (group === "oneOf" && matches !== 1)) return path + " does not match " + group;
    }
    if (schema.not && !schemaError(schema.not, value, root, path)) return path + " matches forbidden schema";
    var type = value === null ? "null" : Array.isArray(value) ? "array" : typeof value;
    var types = schema.type === undefined ? null : Array.isArray(schema.type) ? schema.type : [schema.type];
    if (types && !types.some(function (expected) {
        return expected === "integer" ? typeof value === "number" && Number.isSafeInteger(value) : expected === type;
    })) return path + " has wrong type";
    if (type === "number") {
        if (!Number.isFinite(value)) return path + " is not finite";
        if (schema.minimum !== undefined && value < schema.minimum) return path + " is below minimum";
        if (schema.maximum !== undefined && value > schema.maximum) return path + " is above maximum";
        if (schema.exclusiveMinimum !== undefined && value <= schema.exclusiveMinimum) return path + " is below exclusive minimum";
        if (schema.exclusiveMaximum !== undefined && value >= schema.exclusiveMaximum) return path + " is above exclusive maximum";
    }
    if (type === "string") {
        if (schema.minLength !== undefined && Array.from(value).length < schema.minLength) return path + " is too short";
        if (schema.maxLength !== undefined && Array.from(value).length > schema.maxLength) return path + " is too long";
        if (schema.pattern && !(new RegExp(schema.pattern)).test(value)) return path + " has invalid format";
    }
    if (type === "array") {
        if (schema.minItems !== undefined && value.length < schema.minItems) return path + " has too few items";
        if (schema.maxItems !== undefined && value.length > schema.maxItems) return path + " has too many items";
        for (var i = 0; i < value.length; i++) {
            var itemError = schemaError(schema.items === undefined ? true : schema.items, value[i], root, path + "[" + i + "]");
            if (itemError) return itemError;
        }
    }
    if (type === "object") {
        var required = schema.required || [];
        for (var k = 0; k < required.length; k++) if (!Object.prototype.hasOwnProperty.call(value, required[k])) return path + "." + required[k] + " is required";
        var properties = schema.properties || {};
        for (var key of Object.keys(value)) {
            var rule = Object.prototype.hasOwnProperty.call(properties, key) ? properties[key] : schema.additionalProperties;
            if (rule === undefined) continue;
            var fieldError = schemaError(rule, value[key], root, path + "." + key);
            if (fieldError) return fieldError;
        }
    }
    return "";
}

function eventError(envelope) {
    var schema = eventContracts[envelope.stream + ":" + envelope.event];
    return schema ? schemaError(schema, envelope.data) : "";
}

function requestError(method, params) {
    var contract = contracts[method];
    return contract ? schemaError(contract.params_schema, params) : "";
}
function responseError(method, envelope) {
    var contract = contracts[method];
    if (!contract || !envelope || envelope.ok !== true) return "";
    if (!envelope.data || !Object.prototype.hasOwnProperty.call(envelope.data, contract.response_key)) return "Missing " + contract.response_key + " result";
    return schemaError(contract.result_schema, envelope.data[contract.response_key]);
}
