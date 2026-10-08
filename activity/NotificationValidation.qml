pragma Singleton
import QtQml

// Notification wire-shape checks. Request ownership, revision fences,
// publication and destructive-operation policy remain with their callers.
QtObject {
    function integerIn(value: var, minimum: double, maximum: double): bool {
        return Number.isSafeInteger(value) && value >= minimum && value <= maximum;
    }
    function token(value: var): bool { return typeof value === "string" && value.length > 0; }
    function identity(id: var, created: var): bool {
        return integerIn(id, 1, 4294967295) && integerIn(created, 1, Number.MAX_SAFE_INTEGER);
    }
    function preview(item: var): bool {
        return !!item && identity(item.id, item.created_unix_ms) && token(item.app_key)
            && [item.app_name, item.app_icon, item.summary, item.body].every(text => typeof text === "string");
    }
    function envelope(value: var, view: string, query: string): bool {
        return !!value && value.query === query && value.view === view && token(value.epoch) && token(value.revision);
    }
    function pageEnds(value: var, offset: int, length: int, total: int): bool {
        if (value.offset !== offset || typeof value.anchor_reached !== "boolean") return false;
        const end = offset + length;
        return value.next_offset === null ? end === total : length > 0 && value.next_offset === end && end < total;
    }
}
