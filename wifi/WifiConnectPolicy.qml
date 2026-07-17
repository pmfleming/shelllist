import QtQuick
import "WifiFlow.js" as Flow

Item {
    property var staleSecretKeys: ({})
    property var retryBlockedUntilByAttempt: ({})
    property var lastConnectAp: null
    property string lastConnectAttemptKey: ""
    property string lastConnectSecretFingerprint: ""

    function secretStale(ap) { return !!staleSecretKeys[Flow.secretKey(ap)]; }

    function markSecretStale(ap) {
        if (!ap)
            return;
        staleSecretKeys[Flow.secretKey(ap)] = true;
        staleSecretKeys = Object.assign({}, staleSecretKeys);
    }

    function clearSecretStale(ap) {
        if (!ap)
            return;
        delete staleSecretKeys[Flow.secretKey(ap)];
        staleSecretKeys = Object.assign({}, staleSecretKeys);
    }

    function blockLastConnectRetry(milliseconds) {
        if (lastConnectAttemptKey.length === 0 || milliseconds <= 0)
            return;
        retryBlockedUntilByAttempt[lastConnectAttemptKey + "\n" + lastConnectSecretFingerprint] = Date.now() + milliseconds;
        retryBlockedUntilByAttempt = Object.assign({}, retryBlockedUntilByAttempt);
    }

    function retryDelayRemainingMs(ap, password) {
        const key = Flow.connectAttemptKey(ap) + "\n" + Flow.passwordFingerprint(password);
        return Math.max(0, (retryBlockedUntilByAttempt[key] || 0) - Date.now());
    }

    function rememberConnectAttempt(ap, password) {
        lastConnectAp = ap;
        lastConnectAttemptKey = Flow.connectAttemptKey(ap);
        lastConnectSecretFingerprint = Flow.passwordFingerprint(password);
    }
}
