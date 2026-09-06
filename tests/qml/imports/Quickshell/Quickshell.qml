pragma Singleton

import QtQml

QtObject {
    property var environment: ({})
    function env(name: string): string { return environment[name] || ""; }
}
