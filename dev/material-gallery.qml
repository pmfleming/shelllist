pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ShellRoot {
    id: gallery
    property bool checked: true
    property bool secondaryChecked: false
    property string segment: "first"
    readonly property var fontFamilies: Qt.fontFamilies()

    Component.onCompleted: {
        const scheme = Quickshell.env("SHELLLIST_GALLERY_SCHEME");
        if (scheme === "light" || scheme === "dark")
            Ui.Theme.previewColorScheme = scheme === "dark" ? Qt.Dark : Qt.Light;
    }

    component Swatch: Rectangle {
        id: swatch
        required property string label
        required property color foreground
        implicitHeight: 64
        Layout.fillWidth: true
        radius: 12
        Ui.ThemeText {
            anchors.centerIn: parent
            text: swatch.label
            color: swatch.foreground
            font.pixelSize: 14
        }
    }

    component PaletteSample: Rectangle {
        id: sample
        required property color seed
        required property bool darkMode
        required property string label
        Layout.fillWidth: true
        implicitHeight: 128
        radius: 20
        color: palette.surfaceContainer
        Ui.MaterialPalette {
            id: palette
            seedColor: sample.seed
            dark: sample.darkMode
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            Ui.ThemeText {
                text: sample.label + (sample.darkMode ? " · dark" : " · light")
                color: palette.surfaceText
            }
            RowLayout {
                Layout.fillWidth: true
                Swatch {
                    label: "Primary"
                    color: palette.primary
                    foreground: palette.primaryText
                }
                Swatch {
                    label: "Secondary"
                    color: palette.secondary
                    foreground: palette.secondaryText
                }
                Swatch {
                    label: "Tertiary"
                    color: palette.tertiary
                    foreground: palette.tertiaryText
                }
                Swatch {
                    label: "Error"
                    color: palette.error
                    foreground: palette.errorText
                }
            }
        }
    }

    Window {
        id: window
        title: "Shelllist · Material development gallery"
        width: 1080
        height: Quickshell.env("SHELLLIST_GALLERY_CAPTURE") ? 1120 : 860
        visible: true
        onClosing: Qt.quit()

        // Part of the item tree so offscreen captures include the background.
        Rectangle {
            anchors.fill: parent
            color: Ui.Theme.window
        }
        Flickable {
            anchors.fill: parent
            anchors.margins: 24
            contentHeight: content.implicitHeight
            clip: true
            ColumnLayout {
                id: content
                width: parent.width
                spacing: 16
                Ui.ThemeText {
                    text: "Material visual foundation · development only"
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                }
                Ui.ThemeText {
                    Layout.fillWidth: true
                    text: "Tonal Spot / spec 2021. Fonts below are candidates, not a chosen production face. Tab through real controls to inspect immediate focus; no tooltips."
                    wrapMode: Text.Wrap
                    color: Ui.Theme.mutedText
                }
                RowLayout {
                    Ui.ActionButton {
                        implicitWidth: 150
                        label: Ui.Theme.dark ? "Preview light" : "Preview dark"
                        onClicked: Ui.Theme.previewColorScheme = Ui.Theme.dark ? Qt.Light : Qt.Dark
                    }
                    Ui.ActionButton {
                        implicitWidth: 150
                        label: "Follow desktop"
                        onClicked: Ui.Theme.previewColorScheme = Qt.Unknown
                    }
                    Ui.ThemeText {
                        text: "Desktop seed: " + Ui.Theme.desktopAccent
                        color: Ui.Theme.mutedText
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: window.width < 850 ? 1 : 2
                    columnSpacing: 12
                    rowSpacing: 12
                    PaletteSample {
                        seed: Ui.Theme.desktopAccent
                        darkMode: false
                        label: "Desktop"
                    }
                    PaletteSample {
                        seed: Ui.Theme.desktopAccent
                        darkMode: true
                        label: "Desktop"
                    }
                    PaletteSample {
                        seed: "#6750a4"
                        darkMode: false
                        label: "Purple seed"
                    }
                    PaletteSample {
                        seed: "#6750a4"
                        darkMode: true
                        label: "Purple seed"
                    }
                    PaletteSample {
                        seed: "#009688"
                        darkMode: false
                        label: "Teal seed"
                    }
                    PaletteSample {
                        seed: "#009688"
                        darkMode: true
                        label: "Teal seed"
                    }
                }
                Ui.ThemeText {
                    text: "Expressive controls · hold Space or the pointer to inspect press shapes"
                    font.pixelSize: 18
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 12
                    Ui.ActionButton {
                        width: 100
                        label: "Primary"
                        tone: "accent"
                    }
                    Ui.ActionButton {
                        width: 100
                        label: "Success"
                        tone: "active"
                    }
                    Ui.ActionButton {
                        width: 100
                        label: "Warning"
                        tone: "warning"
                    }
                    Ui.ActionButton {
                        width: 100
                        label: "Error"
                        tone: "danger"
                    }
                    Ui.ActionButton {
                        width: 100
                        label: "Disabled"
                        enabled: false
                    }
                    Ui.FlatIconButton {
                        width: 42
                        height: 42
                        icon: "󰅖"
                        accessibleName: "Icon-only action"
                    }
                    Ui.ToggleSwitch {
                        checked: gallery.checked
                        accessibleName: "Preview selected switch"
                        onToggled: function (value) {
                            gallery.checked = value;
                        }
                    }
                    Ui.ToggleSwitch {
                        checked: gallery.secondaryChecked
                        accessibleName: "Preview unselected switch"
                        onToggled: function (value) {
                            gallery.secondaryChecked = value;
                        }
                    }
                    Ui.ToggleSwitch {
                        checked: true
                        enabled: false
                        accessibleName: "Preview disabled switch"
                    }
                }
                Ui.TextField {
                    Layout.fillWidth: true
                    placeholder: "Normal text editing / immediate focus"
                    Accessible.name: "Preview text field"
                }
                Ui.ValueSlider {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: 50
                    stepSize: 1
                    Accessible.name: "Preview slider"
                }
                Ui.SegmentedControl {
                    Layout.fillWidth: true
                    options: [
                        {
                            value: "first",
                            label: "First"
                        },
                        {
                            value: "second",
                            label: "Second"
                        }
                    ]
                    value: gallery.segment
                    onSelected: function (value) {
                        gallery.segment = value;
                    }
                }
                Ui.ThemeText {
                    text: "Typeface comparison · production choice still open"
                    font.pixelSize: 18
                }
                Repeater {
                    model: ["Roboto Flex", "Noto Sans"]
                    ColumnLayout {
                        required property string modelData
                        readonly property bool available: gallery.fontFamilies.indexOf(modelData) >= 0
                        Layout.fillWidth: true
                        Ui.ThemeText {
                            text: parent.modelData + (parent.available ? "" : " · NOT INSTALLED (no sample)")
                            color: Ui.Theme.mutedText
                        }
                        Text {
                            visible: parent.available
                            Layout.fillWidth: true
                            text: "Applications  ·  Wi-Fi  ·  09:41  ·  Aa 0123456789"
                            font.family: parent.modelData
                            font.pixelSize: 22
                            color: Ui.Theme.text
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }

    // Used only by the offscreen gallery check; never a production surface.
    Timer {
        interval: 500
        running: Quickshell.env("SHELLLIST_GALLERY_SMOKE") === "1"
        onTriggered: {
            const requested = Quickshell.env("SHELLLIST_GALLERY_SCHEME");
            if ((requested === "dark" || requested === "light") && Ui.Theme.dark !== (requested === "dark")) {
                console.error("Gallery mode did not update");
                Qt.exit(1);
                return;
            }
            for (const family of ["Roboto Flex", "Noto Sans"]) {
                if (gallery.fontFamilies.indexOf(family) < 0) {
                    console.error("Missing gallery font: " + family);
                    Qt.exit(1);
                    return;
                }
            }
            const capture = Quickshell.env("SHELLLIST_GALLERY_CAPTURE");
            if (capture) {
                window.contentItem.grabToImage(function (image) {
                    if (!image.saveToFile(capture)) {
                        console.error("Could not save gallery capture");
                        Qt.exit(1);
                    } else {
                        Qt.quit();
                    }
                });
            } else {
                Qt.quit();
            }
        }
    }
}
