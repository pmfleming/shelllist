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
        const sameSource = initialized && source === subscription;
        const sameEpoch = sameSource && epoch === data.epoch;
        if (sameEpoch && data.revision <= revision)
            return false; // duplicate/older record, never roll back
        // New subscriptions need a baseline. A same-source epoch change also
        // requires exact native counter exhaustion, never an unsolicited reset.
        const baseline = data.initial && data.base_revision === 0;
        const ordered = sameEpoch ? !data.initial && data.base_revision === revision
            : baseline && (!sameSource || revision === maximumRevision);
        if (!ordered) {
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
