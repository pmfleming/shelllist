pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

ShellRoot {
    ApplicationController { id: applicationController }

    Ui.ChooserWindowHost {
        controller: applicationController
        applicationId: "launcher"
        displayName: "Applications"
        content: contentComponent
    }

    Component {
        id: contentComponent
        ApplicationContent { controller: applicationController }
    }
}
