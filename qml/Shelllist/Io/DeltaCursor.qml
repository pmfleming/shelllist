import QtQuick

// Ordering only, not a domain projection. The caller must validate the payload
// and fence subscription ownership before presenting a record here.
QtObject {
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
    function validFrame(data: var): bool {
        return !!data && typeof data.epoch === "string" && data.epoch.length > 0
            && typeof data.initial === "boolean" && Number.isSafeInteger(data.revision)
            && Number.isSafeInteger(data.base_revision) && data.base_revision >= 0
            && data.revision >= 1 && data.revision <= maximumRevision
            && data.revision === data.base_revision + 1;
    }
    function follows(subscription: string, data: var): bool {
        const sameSource = initialized && source === subscription;
        if (sameSource && epoch === data.epoch)
            return !data.initial && data.base_revision === revision;
        // Only an authoritative baseline can establish a new owner or epoch.
        return data.initial && data.base_revision === 0 && (!sameSource || revision === maximumRevision);
    }
    function accept(subscription: string, data: var): bool {
        if (!subscription || !validFrame(data)) {
            invalidate();
            return false;
        }
        // A renewal accepts only a new subscription's authoritative baseline.
        if (recovering && source === subscription)
            return false;
        if (initialized && source === subscription && epoch === data.epoch && data.revision <= revision)
            return false; // duplicate/older record, never roll back or demand recovery
        if (!follows(subscription, data)) {
            invalidate();
            return false;
        }
        source = subscription;
        epoch = data.epoch;
        revision = data.revision;
        initialized = true;
        recovering = false;
        return true;
    }
}
