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
    detailsTabEnabled: false
    helpEnabled: controller.uiActive && !controller.discardPrompt && !controller.trial
    helpEntries: [
        { keys: "Right", action: qsTr("Expand selected display") },
        { keys: "Ctrl+Enter", action: qsTr("Preview the whole layout · keep within 20 seconds") }
    ]
    onRefreshRequested: controller.refresh()

    listComponent: Component { DisplayListPane { controller: content.controller } }
    detailsComponent: Component { DisplayDetails { controller: content.controller; uiScale: content.uiScale } }

    Shortcut {
        sequence: "Ctrl+Return"
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
