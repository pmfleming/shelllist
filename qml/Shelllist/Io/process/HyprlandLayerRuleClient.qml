import QtQuick
import Quickshell.Io
Item {
    id: client
    property string pendingRule: ""
    function apply(rule) {
        if (process.running) {
            pendingRule = rule;
            return;
        }
        process.exec(["hyprctl", "keyword", "layerrule", rule]);
    }
    function applyPending() {
        if (pendingRule.length === 0)
            return;
        const rule = pendingRule;
        pendingRule = "";
        apply(rule);
    }
    Process {
        id: process
        onExited: function (exitCode) { client.applyPending(); } // qmllint disable signal-handler-parameters
    }
}
