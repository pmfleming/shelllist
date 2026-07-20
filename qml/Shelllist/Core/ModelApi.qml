pragma Singleton

import QtQuick
import "Model.js" as Implementation

QtObject {
    function action(value) { return Implementation.action(value); }
    function keepOpenAction(id, label, options) { return Implementation.keepOpenAction(id, label, options); }
    function result(value) { return Implementation.result(value); }
}
