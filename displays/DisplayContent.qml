pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content
    required property DisplayController controller
    chooserController: controller
    surfaceName: qsTr("Displays")
    minimumSplitDetailsWidth: 350
    navigationEnabled: !controller.discardPrompt && !controller.layoutDragging && !controller.navigationHelpOpen
    refreshEnabled: !controller.actionInFlight && !controller.trial && navigationEnabled
    detailsTabEnabled: navigationEnabled && controller.detailsOpen && controller.hasSelection && !controller.trial && !controller.actionInFlight
    helpEnabled: controller.uiActive && !controller.discardPrompt && !controller.trial
    helpEntries: [{ keys: "Right", action: qsTr("Expand selected display") }]
    refreshHelp: qsTr("Refresh displays")
    detailsTabHelp: qsTr("Switch Settings / Information")

    listComponent: Component { DisplayListPane { controller: content.controller } }
    detailsComponent: Component { DisplayDetails { controller: content.controller; uiScale: content.uiScale } }

    Ui.SurfaceShortcut {
        sequence: "Ctrl+Return"
        help: qsTr("Preview the whole layout · keep within 20 seconds")
        enabled: content.controller.uiActive && content.controller.detailsOpen && content.controller.canPreview && !content.controller.discardPrompt && !content.controller.navigationHelpOpen
        autoRepeat: false
        onActivated: content.controller.preview()
    }
    DisplayTrialDialog { controller: content.controller }
    Ui.PromptDialog {
        objectName: "discardDisplayDraft"
        visible: content.controller.discardPrompt
        title: qsTr("Discard layout changes?")
        inputVisible: false
        actionsVisible: true
        enterEnabled: false
        instruction: ""
        rejectLabel: qsTr("Keep editing")
        acceptLabel: qsTr("Discard")
        acceptTone: "warning"
        onAccepted: content.controller.discardAndClose()
        onCancelled: {
            content.controller.discardPrompt = false;
            content.controller.editorFocusRequested();
        }
    }
}
