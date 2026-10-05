import QtQuick
import QtQuick.Layouts

Rectangle {
    id: header

    required property real uiScale
    property string filterText: ""
    readonly property bool searchFocused: search.inputActiveFocus
    property string placeholder: "Search…"
    property string icon: ""
    property bool powered: false
    property bool refreshing: false
    property bool powerEnabled: true
    property bool powerVisible: true
    property bool refreshEnabled: true
    property string refreshIcon: "󰑐"
    property bool focusOnCompleted: false
    property bool iconActionEnabled: false
    property string iconAccessibleName: ""
    property string powerAccessibleName: "Power"
    property Component powerAccessory: null
    property string searchActionIcon: ""
    property string searchActionToolTip: ""
    property bool searchActionEnabled: true

    signal querySelectionChanged
    signal filterEdited(string text)
    signal keyPressed(var event)
    signal iconClicked
    signal searchActionRequested
    signal powerRequested
    signal refreshRequested

    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    implicitHeight: scaled(56)
    radius: height / 2
    color: Theme.surfaceRaised

    function scaled(value) {
        return Math.round(value * uiScale);
    }
    function focusSearch() {
        search.focusInput(false);
    }
    function selectionState(): var { return search.selectionState(); }
    function restoreSelection(state: var): void { search.restoreSelection(state); }
    function insertSearchText(text: string): void { search.insertText(text); }

    Component.onCompleted: if (focusOnCompleted)
        Qt.callLater(focusSearch)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: header.scaled(16)
        anchors.rightMargin: header.scaled(8)
        spacing: header.scaled(4)

        ThemeText {
            objectName: "searchLeadingIcon"
            Layout.preferredWidth: header.scaled(24)
            Layout.preferredHeight: header.scaled(24)
            text: "search"
            font.family: Theme.symbolFontFamily
            font.pixelSize: header.scaled(24)
            color: header.searchFocused ? Theme.accent : Theme.mutedText
            Accessible.ignored: true
        }

        // Reuse the native editor/selection/IME boundary, not the form frame.
        TextField {
            id: search
            objectName: "chooserSearchField"
            Layout.fillWidth: true
            Layout.minimumWidth: header.scaled(48)
            Layout.preferredHeight: header.scaled(48)
            leftPadding: header.scaled(8)
            rightPadding: header.scaled(8)
            formStyle: false
            color: "transparent"
            border.width: 0
            focused: false
            fontPixelSize: header.scaled(16)
            text: header.filterText
            placeholder: header.placeholder
            onSelectionChanged: header.querySelectionChanged()
            onEdited: function (text) { header.filterEdited(text); }
            onKeyPressed: function (event) {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & ~Qt.KeypadModifier) === Qt.AltModifier) {
                    // Never fall through to the selected result's primary action.
                    event.accepted = true;
                    if (header.searchActionIcon.length > 0 && header.searchActionEnabled)
                        header.searchActionRequested();
                    return;
                }
                header.keyPressed(event);
            }
        }

        FlatIconButton {
            objectName: "fieldTrailingAction"
            visible: header.searchActionIcon.length > 0
            Layout.preferredWidth: header.scaled(40)
            Layout.preferredHeight: header.scaled(40)
            icon: header.searchActionIcon
            accessibleName: header.searchActionToolTip
            enabled: header.searchActionEnabled
            onClicked: header.searchActionRequested()
        }

        FlatIconButton {
            objectName: "chooserIconButton"
            visible: header.iconActionEnabled
            Layout.preferredWidth: header.scaled(40)
            Layout.preferredHeight: header.scaled(40)
            icon: header.icon
            accessibleName: header.iconAccessibleName
            onClicked: header.iconClicked()
        }

        ToggleSwitch {
            objectName: "chooserPowerToggle"
            visible: header.powerVisible
            Accessible.name: header.powerAccessibleName
            Layout.preferredWidth: header.scaled(52)
            Layout.preferredHeight: header.scaled(40)
            checked: header.powered
            enabled: header.powerEnabled
            onToggled: header.powerRequested()
        }

        Loader {
            visible: sourceComponent !== null
            sourceComponent: header.powerAccessory
            Layout.preferredWidth: (item as Item)?.implicitWidth ?? 0
            Layout.preferredHeight: header.scaled(40)
        }

        FlatIconButton {
            objectName: "chooserRefreshButton"
            Layout.preferredWidth: header.scaled(40)
            Layout.preferredHeight: header.scaled(40)
            icon: header.refreshIcon
            accessibleName: qsTr("Refresh")
            flatIconColor: header.refreshing ? Theme.accent : Theme.mutedText
            enabled: header.refreshEnabled && !header.refreshing
            onClicked: header.refreshRequested()
        }
    }
}
