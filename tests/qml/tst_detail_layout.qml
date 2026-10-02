pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import Shelllist.Core as Core
import "../../wifi" as Wifi

DaemonTestCase {
    id: testCase
    name: "DetailLayout"
    when: windowShown
    visible: true
    width: 900
    height: 900

    Component {
        id: wifiFactory
        Item {
            id: scene
            property bool advancedView: false
            property alias controller: controller
            property alias cards: cards
            property alias advancedPage: advancedPage
            Wifi.WifiPromptController { id: prompt }
            Wifi.WifiController {
                id: controller
                prompt: prompt
                detailActions: [
                    Core.Model.settingToggle("autoconnect", "Auto-connect", true),
                    Core.Model.settingToggle("randomized-mac", "Randomize MAC address", false),
                    Core.Model.settingToggle("send-hostname", "Send device name", true)
                ]
            }
            Wifi.NetworkDetailCards {
                id: cards
                anchors.fill: parent
                visible: !scene.advancedView
                controller: scene.controller
                accessPoint: ({})
                sectionSpacing: 12
                connectionCardHeight: 220
                networkCardHeight: 130
            }
            Wifi.AdvancedSettingsPage {
                id: advancedPage
                anchors.fill: parent
                visible: scene.advancedView
                controller: scene.controller
            }
        }
    }
    Component {
        id: wrappedCardFactory
        Ui.DetailColumnCard {
            width: 300
            title: "Settings"
            Ui.ToggleRow {
                objectName: "wrappedToggle"
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                wrapTitle: true
                title: "A long setting name that must wrap without overlapping the next control"
                subtitle: "Supporting information"
            }
            Ui.TextField {
                objectName: "followingControl"
                Layout.fillWidth: true
            }
        }
    }
    Component {
        id: gridFactory
        Ui.DetailCard {
            width: 300
            title: "Diagnostics"
            entries: [
                {label: "A long diagnostic label that wraps to several lines", value: "value"},
                {label: "Address", value: "A long address ".repeat(10), valueWidth: 600},
                {label: "Status", value: "Ready"},
                {label: "Interface", value: "wlan0"}
            ]
        }
    }

    function init() { failOnWarning(/.*/); }

    function contained(item, container) {
        tryVerify(() => {
            const top = item.mapToItem(container, 0, 0);
            const bottom = item.mapToItem(container, item.width, item.height);
            return top.x >= -1 && top.y >= -1 && bottom.x <= container.width + 1 && bottom.y <= container.height + 1;
        }, 1000, item.objectName + " must stay inside " + container.objectName);
    }

    function test_wifiCards_data() {
        return [{tag: "compact", width: 320, height: 240}, {tag: "wide", width: 680, height: 700}];
    }
    function test_wifiCards(data) {
        const scene = createTemporaryObject(wifiFactory, testCase, {width: data.width, height: data.height});
        verify(scene !== null);
        wait(0);
        const card = findChild(scene.cards, "wifiPrimarySettings");
        const diagnostics = findChild(scene.cards, "wifiNetworkDiagnostics");
        let previousBottom = 0;
        for (const id of ["autoconnect", "randomized-mac", "send-hostname"]) {
            const toggle = findChild(card, "detailSetting:" + id);
            contained(toggle, card);
            verify(toggle.height >= 56);
            const top = toggle.mapToItem(card, 0, 0).y;
            verify(top >= previousBottom);
            previousBottom = top + toggle.height;
        }
        verify(diagnostics.y >= card.y + card.height + scene.cards.cardSpacing - 1);
        verify(diagnostics.informationOnly);
        compare(findChild(diagnostics, "wifiNetworkDiagnosticsToggle"), null);
        wait(0);
        let bottom = 0;
        for (let i = 0; i < diagnostics.content.length; ++i) {
            const child = diagnostics.content[i];
            contained(child, diagnostics);
            verify(child.height >= child.implicitHeight - 1);
            const top = child.mapToItem(diagnostics, 0, 0).y;
            verify(top >= bottom);
            bottom = top + child.height;
        }
        tryVerify(() => scene.cards.contentHeight >= diagnostics.y + diagnostics.height);
        if (data.height === 240)
            verify(scene.cards.interactive, "short viewports scroll rather than squeeze cards");
        const originalHeight = card.height;
        scene.controller.detailActions = scene.controller.detailActions.concat([
            Core.Model.settingToggle("extra", "Additional setting", false, {subtitle: "Supporting information"})
        ]);
        tryVerify(() => card.height > originalHeight);
        contained(findChild(card, "detailSetting:extra"), card);
        tryVerify(() => diagnostics.y >= card.y + card.height + scene.cards.cardSpacing - 1);

        scene.advancedView = true;
        scene.controller.advanced.section = "hardware";
        tryVerify(() => findChild(scene.advancedPage, "wifiIpSettingsCard") !== null);
        const ipCard = findChild(scene.advancedPage, "wifiIpSettingsCard");
        wait(0);
        previousBottom = 0;
        for (const name of ["wifiIpFamily", "wifiIpEnabled", "wifiIpAutomatic", "wifiDnsAutomatic", "wifiIpAddress", "wifiIpPrefix", "wifiIpGateway", "wifiDnsServers", "wifiDnsSearch"]) {
            const control = findChild(ipCard, name);
            contained(control, ipCard);
            const top = control.mapToItem(ipCard, 0, 0).y;
            verify(top >= previousBottom);
            previousBottom = top + control.height;
        }
        verify(previousBottom <= ipCard.height - ipCard.verticalContentPadding + 1);

        scene.controller.bandStatus = {path: "/test", selected: "auto", available: ["2.4", "5", "6"]};
        scene.controller.advanced.section = "security";
        tryVerify(() => findChild(scene.advancedPage, "wifiSecurityControls") !== null);
        const security = findChild(scene.advancedPage, "wifiSecurityControls");
        const technical = findChild(scene.advancedPage, "wifiSecurityDiagnostics");
        for (const name of ["wifiBand", "wifiMacPolicy", "castingToggle"])
            contained(findChild(security, name), security);
        tryVerify(() => technical.y >= security.y + security.height + scene.advancedPage.sectionSpacing - 1);
    }

    function test_wrappedSettingsGrowBeforeFollowingControls() {
        const card = createTemporaryObject(wrappedCardFactory, testCase);
        wait(0);
        const toggle = findChild(card, "wrappedToggle");
        const next = findChild(card, "followingControl");
        verify(toggle.height >= toggle.implicitHeight - 1);
        verify(next.y >= toggle.y + toggle.height);
        contained(toggle, card);
        contained(next, card);
    }

    function test_diagnosticGridContainsWrappedLabelsAndResizes() {
        const card = createTemporaryObject(gridFactory, testCase);
        for (const width of [300, 680, 240]) {
            card.width = width;
            wait(0);
            const grid = card.content[0];
            contained(grid, card);
            compare(grid.columns, width < 400 ? 1 : 2);
            const fields = grid.children.filter(child => child.label !== undefined);
            compare(fields.length, 4);
            for (const field of fields) {
                contained(field, grid);
                for (const text of field.children)
                    contained(text, field);
            }
            for (let index = grid.columns; index < fields.length; ++index)
                verify(fields[index].y >= fields[index - grid.columns].y + fields[index - grid.columns].height);
        }
    }
}
