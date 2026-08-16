pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BarPresentation.js" as Presentation

Item {
    id: root

    required property BarController controller
    required property string screenName
    property date now: new Date()

    Rectangle {
        anchors.fill: parent
        color: Ui.Theme.withAlpha(Ui.Theme.window, 0.92)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Ui.Theme.border
        }
    }

    WorkspaceStrip {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        controller: root.controller
        screenName: root.screenName
    }

    BarAction {
        id: mediaItem
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: root.controller.activePlayer !== null
        width: Math.min(420, implicitWidth)
        text: Presentation.mediaText(root.controller.activePlayer)
        tooltipText: root.controller.activePlayer
            ? (root.controller.activePlayer.artist || root.controller.activePlayer.identity || "")
                + (root.controller.activePlayer.album ? "\n" + root.controller.activePlayer.album : "") : ""
        elide: Text.ElideRight
        onPrimaryTriggered: root.controller.mediaOperation("play-pause")
        onSecondaryTriggered: root.controller.mediaOperation("next")
        onMiddleTriggered: root.controller.mediaOperation("previous")
    }

    Row {
        id: rightModules
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 2

        BarTray { height: parent.height }

        BarAction {
            height: parent.height
            text: Presentation.networkIcon(root.controller.networkStatus)
            tooltipText: Presentation.networkTooltip(root.controller.networkStatus)
            foreground: Presentation.networkKind(root.controller.networkStatus) === "disconnected"
                ? Ui.Theme.mutedText : Ui.Theme.text
            onPrimaryTriggered: root.controller.openWifi()
            onSecondaryTriggered: root.controller.openPortalFallback()
        }

        BarAction {
            height: parent.height
            visible: root.controller.updates.available && root.controller.updates.ready
            text: "󰚰"
            tooltipText: "A checked and built NixOS update is waiting for automatic safety or manual approval"
            foreground: Ui.Theme.accent
            fontWeight: Ui.Theme.fontWeightBold
            onPrimaryTriggered: root.controller.openUpdateJournal()
        }

        BarAction {
            height: parent.height
            text: ""
            tooltipText: Presentation.bluetoothTooltip(root.controller.bluetoothController)
            foreground: root.controller.bluetoothController && root.controller.bluetoothController.powered
                ? Ui.Theme.text : Ui.Theme.mutedText
            onPrimaryTriggered: root.controller.openBluetooth()
        }

        BarAction {
            height: parent.height
            text: Presentation.audioIcon(root.controller.audio)
            tooltipText: root.controller.audio.available
                ? (root.controller.audio.sink_description || "Audio") + ": "
                    + root.controller.audio.volume_percent + "%"
                    + (root.controller.audio.muted ? " (muted)" : "")
                : "Audio unavailable"
            foreground: root.controller.audio.muted ? Ui.Theme.mutedText : Ui.Theme.text
            onPrimaryTriggered: root.controller.openAudioMixer()
            onSecondaryTriggered: root.controller.toggleMuted()
            onWheelUp: root.controller.adjustAudio(5)
            onWheelDown: root.controller.adjustAudio(-5)
        }

        BarAction {
            height: parent.height
            visible: root.controller.brightness.available
            text: "󰃠"
            tooltipText: "Brightness: " + root.controller.brightness.percent
                + "%\nLeft click: brighter\nRight click: dimmer"
            onPrimaryTriggered: root.controller.adjustBrightness(5)
            onSecondaryTriggered: root.controller.adjustBrightness(-5)
            onWheelUp: root.controller.adjustBrightness(5)
            onWheelDown: root.controller.adjustBrightness(-5)
        }

        BarAction {
            height: parent.height
            visible: root.controller.battery.available
            text: Presentation.batteryIcon(root.controller.battery) + " "
                + root.controller.battery.percentage + "%"
            tooltipText: Presentation.batteryTooltip(root.controller.battery)
            interactive: false
            foreground: root.controller.battery.charging || root.controller.battery.plugged
                ? Ui.Theme.active : root.controller.battery.critical
                    ? Ui.Theme.danger : root.controller.battery.warning
                        ? Ui.Theme.warning : Ui.Theme.text
        }

        BarAction {
            height: parent.height
            visible: root.controller.powerProfile.available
            text: Presentation.powerProfileIcon(root.controller.powerProfile)
            tooltipText: "Power profile: " + root.controller.powerProfile.profile
                + "\nDriver: " + (root.controller.powerProfile.driver || "unknown")
            interactive: false
            foreground: root.controller.powerProfile.profile === "performance"
                ? Ui.Theme.danger : root.controller.powerProfile.profile === "power-saver"
                    ? Ui.Theme.active : Ui.Theme.accent
        }

        BarAction {
            height: parent.height
            text: " " + (root.controller.notifications.count || 0)
            tooltipText: "Notifications: " + (root.controller.notifications.count || 0)
                + "\nLeft click: open history\nRight click: toggle do not disturb"
                + (root.controller.notifications.dnd ? "\nDo not disturb is on" : "")
            foreground: root.controller.notifications.dnd ? Ui.Theme.mutedText : Ui.Theme.text
            onPrimaryTriggered: root.controller.toggleNotifications()
            onSecondaryTriggered: root.controller.toggleDnd()
        }

        BarAction {
            height: parent.height
            visible: root.controller.timezone.available
            text: "󰅐 " + root.controller.timezone.city
            tooltipText: "Timezone city: " + root.controller.timezone.city
                + "\nTimezone is updated automatically from location"
            onPrimaryTriggered: root.controller.openTimezoneDetails()
        }

        BarAction {
            height: parent.height
            text: Qt.formatDateTime(root.now, "ddd dd MMM  HH:mm")
            tooltipText: Qt.formatDateTime(root.now, "yyyy-MM-dd") + " "
                + root.controller.timezone.abbreviation + " "
                + Presentation.utcOffset(root.controller.timezone.utc_offset_seconds)
            interactive: false
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }
}
