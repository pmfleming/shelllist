pragma Singleton

import QtQuick
import "Model.js" as Implementation

QtObject {
    function action(value) { return Implementation.action(value); }
    function result(value) { return Implementation.result(value); }
}
