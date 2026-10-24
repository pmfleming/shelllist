import QtQuick

// Ordering only, not a domain projection. The caller must validate the payload
// and fence subscription ownership before presenting a record here.
QtObject {
    id: cursor
    property string source: ""
    property string epoch: ""
    property double revision: 0
    property bool initialized: false
    property bool recovering: false
    readonly property double maximumRevision: 9007199254740991
    signal gapDetected()

    function reset(): void {
        source = "";
        epoch = "";
        revision = 0;
        initialized = false;
        recovering = false;
    }
    function invalidate(): void {
        if (recovering)
            return;
        recovering = true;
        gapDetected();
    }
    function accept(subscription: string, data: var): bool {
        if (!subscription || !data || typeof data.epoch !== "string" || !data.epoch
                || typeof data.initial !== "boolean" || !Number.isSafeInteger(data.revision)
                || !Number.isSafeInteger(data.base_revision) || data.base_revision < 0
                || data.revision < 1 || data.revision > maximumRevision
                || data.revision !== data.base_revision + 1) {
            invalidate();
            return false;
        }
        // A renewal accepts only a new subscription's authoritative baseline.
        if (recovering && source === subscription)
            return false;
        if (!initialized || source !== subscription) {
            if (!data.initial || data.base_revision !== 0) {
                invalidate();
                return false;
            }
        } else if (epoch !== data.epoch) {
            // Native counter exhaustion is the only same-subscription epoch
            // transition. Other changes require a newly owned subscription.
            if (revision !== maximumRevision || !data.initial || data.base_revision !== 0) {
                invalidate();
                return false;
            }
        } else {
            if (data.revision <= revision)
                return false; // duplicate/older record, never roll back
            if (data.initial || data.base_revision !== revision) {
                invalidate();
                return false;
            }
        }
        source = subscription;
        epoch = data.epoch;
        revision = data.revision;
        initialized = true;
        recovering = false;
        return true;
    }
}
