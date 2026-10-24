.pragma library

var schemaVersion = 1;
var idPattern = /^[a-z0-9][a-z0-9._-]*$/;
var actionRoles = ["default", "secondary", "destructive"];
var actionKinds = ["command", "toggle"];
var closePolicies = ["provider-default", "close", "keep-open"];
var presentationGroups = ["primary", "toolbar", "settings", "overflow"];
var tones = ["normal", "active", "danger", "warning"];

function fail(path, message) {
    throw new Error(path + ": " + message);
}
function objectOrEmpty(value) {
    return value && typeof value === "object" && !Array.isArray(value) ? value : ({});
}
function stringValue(value, fallback) {
    return value === undefined || value === null ? fallback : String(value);
}
function nonEmptyString(value, path) {
    const result = stringValue(value, "").trim();
    if (result.length === 0)
        fail(path, "must be a non-empty string");
    return result;
}
function identifier(value, path) {
    const result = nonEmptyString(value, path);
    if (!idPattern.test(result))
        fail(path, "must match " + idPattern);
    return result;
}
function finiteNumber(value, fallback) {
    const result = Number(value);
    return Number.isFinite(result) ? result : fallback;
}
function booleanValue(value, fallback) {
    return value === undefined || value === null ? fallback : !!value;
}
function enumValue(value, allowed, fallback, path) {
    const result = stringValue(value, fallback);
    if (allowed.indexOf(result) < 0)
        fail(path, "unsupported value " + JSON.stringify(result));
    return result;
}
function stringList(values) {
    if (!Array.isArray(values))
        return [];
    const seen = new Set();
    const result = [];
    values.forEach(function (value) {
        const text = stringValue(value, "").trim();
        if (text.length > 0 && !seen.has(text)) {
            seen.add(text);
            result.push(text);
        }
    });
    return result;
}
function ensureUnique(items, field, path) {
    const seen = new Set();
    items.forEach(function (item) {
        const value = item[field];
        if (seen.has(value))
            fail(path, "duplicate " + field + " " + JSON.stringify(value));
        seen.add(value);
    });
}

function provider(input) {
    const source = objectOrEmpty(input);
    return {
        schemaVersion: schemaVersion,
        id: identifier(source.id, "provider.id"),
        name: nonEmptyString(source.name, "provider.name"),
        icon: stringValue(source.icon, ""),
        priority: finiteNumber(source.priority, 0),
        enabled: booleanValue(source.enabled, true),
        prefixes: stringList(source.prefixes),
        capabilities: Object.assign({
            query: true,
            actions: true,
            preview: false,
            subscriptions: false
        }, objectOrEmpty(source.capabilities)),
        metadata: objectOrEmpty(source.metadata)
    };
}

function action(input) {
    const source = objectOrEmpty(input);
    const presentationSource = objectOrEmpty(source.presentation), stateSource = objectOrEmpty(source.state), confirmationSource = objectOrEmpty(source.confirmation);
    const role = enumValue(source.role, actionRoles, "secondary", "action.role"), kind = enumValue(source.kind, actionKinds, "command", "action.kind");
    const presentation = {
        group: enumValue(presentationSource.group, presentationGroups, role === "default" ? "primary" : "overflow", "action.presentation.group"),
        tone: enumValue(presentationSource.tone, tones, role === "destructive" ? "danger" : "normal", "action.presentation.tone")
    };
    return {
        schemaVersion: schemaVersion,
        id: identifier(source.id, "action.id"),
        label: nonEmptyString(source.label, "action.label"),
        icon: stringValue(source.icon, ""),
        shortcut: stringValue(source.shortcut, ""),
        accessKey: stringValue(source.accessKey, "").trim().toUpperCase(),
        accessModifier: enumValue(source.accessModifier, ["Alt", "Ctrl"], "Alt", "action.accessModifier"),
        role: role,
        kind: kind,
        enabled: booleanValue(source.enabled, true),
        visible: booleanValue(source.visible, true),
        closePolicy: enumValue(source.closePolicy, closePolicies, "provider-default", "action.closePolicy"),
        confirmation: {
            required: booleanValue(confirmationSource.required, false),
            title: stringValue(confirmationSource.title, ""),
            message: stringValue(confirmationSource.message, "")
        },
        state: {
            checked: booleanValue(stateSource.checked, false)
        },
        presentation: presentation,
        metadata: objectOrEmpty(source.metadata)
    };
}

function keepOpenAction(id, label, options) {
    return action(Object.assign({}, objectOrEmpty(options), {
        id: id,
        label: label,
        closePolicy: "keep-open"
    }));
}

// Shared presentation contract; capability checks and effects stay with providers.
function settingToggle(id, label, checked, options) {
    const source = objectOrEmpty(options);
    return keepOpenAction(id, label, Object.assign({}, source, {
        kind: "toggle",
        state: {
            checked: checked
        },
        presentation: Object.assign({
            group: "settings"
        }, objectOrEmpty(source.presentation))
    }));
}

// Select presentation only: disabled actions keep their order/shortcut slots.
// Unnormalized toolbar descriptors may opt into a fallback group.
function visibleActions(actions, group, defaultGroup) {
    return (actions || []).filter(item => item.visible !== false && (group === undefined || ((item.presentation || {}).group || defaultGroup) === group));
}

function actionList(values) {
    const result = (Array.isArray(values) ? values : []).map(action);
    ensureUnique(result, "id", "result.actions");
    const visiblePrimary = visibleActions(result, "primary");
    if (visiblePrimary.length > 1)
        fail("result.actions", "must expose at most one visible primary action");
    return result;
}

function resultKey(providerId, resultId) {
    return providerId + "::" + encodeURIComponent(resultId);
}

function result(input) {
    const source = objectOrEmpty(input);
    const providerId = identifier(source.providerId, "result.providerId");
    const id = nonEmptyString(source.id, "result.id");
    const actions = actionList(source.actions);
    const primaryActionId = stringValue(source.primaryActionId, "");
    const primaryAction = actions.find(function (item) {
        return item.id === primaryActionId;
    });
    if (primaryActionId.length > 0 && actions.length > 0 && !primaryAction)
        fail("result.primaryActionId", "does not reference an action");
    if (primaryAction && primaryAction.presentation.group !== "primary")
        fail("result.primaryActionId", "must reference a primary presentation action");
    return {
        schemaVersion: schemaVersion,
        providerId: providerId,
        providerPriority: finiteNumber(source.providerPriority, 0),
        id: id,
        key: resultKey(providerId, id),
        title: nonEmptyString(source.title, "result.title"),
        subtitle: stringValue(source.subtitle, ""),
        icon: stringValue(source.icon, ""),
        score: finiteNumber(source.score, 0),
        keywords: stringList(source.keywords),
        badges: stringList(source.badges),
        primaryActionId: primaryActionId,
        actions: actions,
        preview: Object.assign({
            kind: "none"
        }, objectOrEmpty(source.preview)),
        state: objectOrEmpty(source.state),
        payload: source.payload === undefined ? null : source.payload,
        metadata: objectOrEmpty(source.metadata)
    };
}

function resultList(values) {
    const results = (Array.isArray(values) ? values : []).map(result);
    ensureUnique(results, "key", "results");
    return results;
}

function indexByKey(values, key) {
    if (!key)
        return -1;
    return (Array.isArray(values) ? values : []).findIndex(function (item) {
        return item.key === key;
    });
}
function actionById(actions, id) {
    return (Array.isArray(actions) ? actions : []).find(function (item) {
        return item.id === id;
    }) || null;
}

function queryRequest(input) {
    const source = objectOrEmpty(input);
    return {
        schemaVersion: schemaVersion,
        id: nonEmptyString(source.id, "query.id"),
        generation: Math.max(0, Math.floor(finiteNumber(source.generation, 0))),
        text: stringValue(source.text, ""),
        limit: Math.max(1, Math.floor(finiteNumber(source.limit, 50))),
        exact: booleanValue(source.exact, false),
        providerIds: stringList(source.providerIds),
        context: objectOrEmpty(source.context)
    };
}

function executionRequest(input) {
    const source = objectOrEmpty(input);
    const selectedResult = result(source.result);
    const selectedAction = action(source.action);
    if (selectedAction.enabled !== true || selectedAction.visible !== true)
        fail("execution.action", "must be visible and enabled");
    return {
        schemaVersion: schemaVersion,
        id: nonEmptyString(source.id, "execution.id"),
        providerId: selectedResult.providerId,
        resultId: selectedResult.id,
        resultKey: selectedResult.key,
        actionId: selectedAction.id,
        result: selectedResult,
        action: selectedAction,
        context: objectOrEmpty(source.context)
    };
}
