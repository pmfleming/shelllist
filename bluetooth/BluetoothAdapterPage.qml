import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property alias editing: settings.editing
    readonly property string selectedTab: controller.adapterSettingsTab

    onSelectedTabChanged: {
        page.cancelFlick();
        page.contentY = 0;
    }

    ColumnLayout {
        width: parent.width
        spacing: Ui.Theme.spacingMd

        BluetoothListOptions {
            Layout.fillWidth: true
            visible: page.selectedTab === "general"
            controller: page.controller
        }
        BluetoothAdapterSettings {
            id: settings
            Layout.fillWidth: true
            controller: page.controller
        }
    }
}
