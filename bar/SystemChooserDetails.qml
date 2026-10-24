pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BarMediaPresentation.js" as Media

// Detail fields share one typed owner, independently of list/menu lifecycle.
Ui.ActionDetailsPane {
    id: details
    required property SystemChooserController controller
    chooserController: controller
    uiScale: 1
    title: controller.selectedPlayer ? Media.heading(controller.selectedPlayer) : controller.selectedResult ? controller.selectedResult.title : ""
    subtitle: controller.selectedPlayer ? Media.identityLabel(controller.selectedPlayer) : controller.selectedResult ? controller.selectedResult.subtitle : ""
    icon: controller.selectedResult ? controller.selectedResult.icon : ""
    actions: controller.detailActions.filter(action => !["inspect", "quieter", "louder"].includes(action.id)).map(action => Object.assign({}, action, {
            presentation: Object.assign({}, action.presentation, {
                group: controller.kind === "media" ? Media.actionGroup(controller.selectedPlayer, action.id) : action.id === "activate" ? "primary" : "toolbar"
            })
        }))
    Ui.DetailFlickable {
        anchors.fill: parent
        viewMemory: details.controller.viewMemory
        memoryTab: "details"
        Column {
            width: parent.width
            spacing: Ui.Theme.spacingMd
            Ui.DetailColumnCard {
                visible: details.controller.kind === "audio" && details.controller.direction === "output"
                title: qsTranslate("SystemChooserContent", "Output volume")
                RowLayout {
                    Layout.fillWidth: true
                    Ui.ThemeText {
                        objectName: "audioVolumeValue"
                        Layout.fillWidth: true
                        text: details.controller.barController && Number.isFinite(details.controller.barController.audio.volume_percent) ? details.controller.barController.audio.volume_percent + "%" : qsTranslate("SystemChooserContent", "Not reported")
                        font.pixelSize: Ui.Theme.fontSizeHeading
                        Accessible.name: qsTranslate("SystemChooserContent", "Volume: %1").arg(text)
                    }
                    Ui.SurfaceActionRow {
                        actionObjectNamePrefix: "audioVolume-"
                        Layout.preferredWidth: 2 * Ui.Theme.formActionSize + Ui.Theme.spacingSm
                        headerCommands: false
                        compactSecondaryActions: true
                        actions: details.controller.kind === "audio" ? details.controller.detailActions.filter(action => ["quieter", "louder"].includes(action.id)).map(action => Object.assign({}, action, {presentation: {group: "toolbar"}})) : []
                        onTriggered: function (actionId) {
                            details.controller.triggerDetailAction(actionId);
                        }
                    }
                }
            }
            Ui.ToggleRow {
                objectName: "audioMute"
                visible: details.controller.kind === "audio"
                title: details.controller.direction === "input" ? qsTranslate("SystemChooserContent", "Mute microphone") : qsTranslate("SystemChooserContent", "Mute output")
                checked: details.controller.muted
                enabled: details.controller.hasSelection && !details.controller.actionInFlight
                onClicked: details.controller.toggleAudioMuted()
            }
            MediaPlaybackCard {
                objectName: "mediaPlayback"
                visible: details.controller.kind === "media"
                player: details.controller.selectedPlayer
                active: details.controller.uiActive && !!details.controller.barController && details.controller.barController.backend.ready
            }
            Ui.DetailColumnCard {
                objectName: "mediaPreferences"
                visible: details.controller.kind === "media"
                RowLayout {
                    Layout.fillWidth: true
                    Ui.ToggleRow {
                        objectName: "mediaPlayerPin"
                        Layout.fillWidth: true
                        title: qsTranslate("SystemChooserContent", "Pin to bar")
                        accessibleName: qsTranslate("SystemChooserContent", "Pin this session to the bar until it exits")
                        checked: details.controller.playerPinned
                        enabled: details.controller.mediaPreferencesSupported && !details.controller.actionInFlight
                        onClicked: details.controller.setMediaSelection(!checked)
                    }
                    Ui.ActionButton {
                        icon: "autorenew"
                        objectName: "mediaAutomatic"
                        accessKey: "A"
                        sizeRole: "secondary"
                        uiScale: Ui.Theme.expandedSecondaryActionScale
                        visible: details.controller.mediaPreferencesSupported && !!details.controller.barController.media.pinned_player && !details.controller.playerPinned
                        label: qsTranslate("SystemChooserContent", "Resume automatic player selection")
                        enabled: details.controller.mediaPreferencesSupported && !details.controller.actionInFlight
                        onClicked: details.controller.setMediaSelection(false)
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Ui.Theme.border
                }
                Ui.FormField {
                    Layout.fillWidth: true
                    label: qsTranslate("SystemChooserContent", "Bar controls")
                    icon: "tune"
                    Ui.DropDownList {
                        objectName: "mediaControlMode"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        compact: true
                        Accessible.name: qsTranslate("SystemChooserContent", "Bar controls")
                        value: details.controller.selectedPlayer ? details.controller.selectedPlayer.control_mode || "automatic" : "automatic"
                        options: [
                            {value: "automatic", label: qsTranslate("SystemChooserContent", "Automatic"), icon: "autorenew"},
                            {value: "tracks", label: qsTranslate("SystemChooserContent", "Previous/next track"), icon: "skip_next"},
                            {value: "seek", label: qsTranslate("SystemChooserContent", "Seek ±30 seconds"), icon: "replay_30"}
                        ]
                        enabled: details.controller.mediaPreferencesSupported && !details.controller.actionInFlight
                        onSelected: function (value) {
                            details.controller.setMediaMode(value);
                        }
                    }
                }
            }
        }
    }
}
