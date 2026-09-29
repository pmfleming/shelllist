pragma Singleton

import QtQuick
import "Model.js" as Implementation

QtObject {
    function action(value) {
        return Implementation.action(value);
    }
    function keepOpenAction(id, label, options) {
        return Implementation.keepOpenAction(id, label, options);
    }
    function settingToggle(id, label, checked, options) {
        return Implementation.settingToggle(id, label, checked, options);
    }
    function visibleActions(actions, group, defaultGroup) {
        return Implementation.visibleActions(actions, group, defaultGroup);
    }
    function result(value) {
        return Implementation.result(value);
    }
}
