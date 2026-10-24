import QtQuick

// Full-state order, not delivery order. Owners validate payloads and fence the
// transport/subscription before calling accept. Publication must be synchronous.
QtObject {
    property string epoch: ""
    property double revision: 0
    property string error: ""
    readonly property double maximumRevision: 9007199254740991

    function reset() {
        epoch = "";
        revision = 0;
        error = "";
    }

    function accept(state, publish) {
        error = "";
        if (!state || typeof state !== "object" || Array.isArray(state)
                || typeof state.epoch !== "string" || !state.epoch
                || !Number.isSafeInteger(state.revision) || state.revision < 1
                || state.revision > maximumRevision
                || (state.previous_epoch !== undefined
                    && (typeof state.previous_epoch !== "string" || !state.previous_epoch
                        || state.previous_epoch === state.epoch))) {
            error = "Missing or malformed native snapshot watermark; matching daemon required";
            return false;
        }
        if (epoch === state.epoch && state.revision <= revision)
            return false;
        if (epoch && epoch !== state.epoch && state.previous_epoch !== epoch)
            return false; // unrelated/retired epoch; never roll back
        // Never consume a revision whose payload failed validation/publication.
        publish();
        epoch = state.epoch;
        revision = state.revision;
        return true;
    }
}
