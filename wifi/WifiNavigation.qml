import QtQuick

Item {
    required property var controller

    function accept(event, action) { action(); event.accepted = true; }
    function isEnter(key) { return key === Qt.Key_Return || key === Qt.Key_Enter; }
    function isPlainHotkey(event, key) { return event.key === key && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier); }
    function move(delta) { controller.selectionModel.move(delta); }

    function openDetails() {
        if (controller.detailsOpen)
            return;
        controller.detailsOpen = true;
        controller.detailsExpansionProgress = 1;
        Qt.callLater(controller.windowHost.requestWindowPlacement);
    }

    function closeDetails() {
        if (!controller.detailsOpen)
            return;
        controller.detailsOpen = false;
        controller.detailsExpansionProgress = 0;
        Qt.callLater(controller.windowHost.requestWindowPlacement);
    }

    function toggleDetails() { controller.detailsOpen ? closeDetails() : openDetails(); }
    function focusListTop() { controller.selectedIndex = 0; controller.focusListTopRequested(); }
    function focusSearch() { controller.focusSearchRequested(); }

    function handleBinding(event, bindings) {
        for (let index = 0; index < bindings.length; index++)
            if (event.key === bindings[index][0])
                return accept(event, bindings[index][1]);
    }

    function paneBindings(downAction) {
        return [
            [Qt.Key_Escape, controller.closeRequested],
            [Qt.Key_Down, downAction],
            [Qt.Key_Up, function () { move(-1); }],
            [Qt.Key_Right, openDetails],
            [Qt.Key_Left, closeDetails],
            [Qt.Key_F6, controller.openHiddenNetworkPrompt],
            [Qt.Key_F5, controller.refresh]
        ];
    }

    function handleSearchKey(event) {
        if (controller.prompt.open)
            return;
        if (isEnter(event.key))
            return accept(event, controller.primarySelected);
        return handleBinding(event, paneBindings(focusListTop));
    }

    function handleDetailHotkey(event) {
        if (!controller.detailsOpen)
            return false;
        const bindings = [
            [Qt.Key_C, controller.canConnectDetail, controller.connectSelected],
            [Qt.Key_D, controller.canDisconnectDetail, controller.disconnectSelected],
            [Qt.Key_F, controller.canForgetProfile, controller.forgetSelected],
            [Qt.Key_I, function () { return controller.hasSelection; }, controller.openPortal],
            [Qt.Key_S, controller.canShareSelected, controller.shareSelected],
            [Qt.Key_A, controller.canToggleAutoconnectProfile, controller.toggleAutoconnectSelected],
            [Qt.Key_R, controller.canSetMacRandomizationProfile, controller.toggleRandomizedMacSelected],
            [Qt.Key_N, controller.canSetSendHostnameProfile, controller.toggleSendHostnameSelected]
        ];
        const binding = bindings.find(function (item) { return isPlainHotkey(event, item[0]) && item[1](); });
        if (!binding)
            return false;
        accept(event, binding[2]);
        return true;
    }

    function handleListKey(event) {
        if (isEnter(event.key))
            return accept(event, controller.primarySelected);
        if (handleDetailHotkey(event))
            return;
        if (event.key === Qt.Key_Up && controller.selectedIndex <= 0)
            return accept(event, focusSearch);
        return handleBinding(event, paneBindings(function () { move(1); }));
    }
}
