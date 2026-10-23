pragma Singleton
import QtQml

QtObject {
    readonly property var stateLabels: ({
        "charge-paused": qsTr("Charging paused at limit"),
        "charging-inhibited": qsTr("Charging inhibited"),
        "calibrating": qsTr("Calibrating battery"),
        "fully-charged": qsTr("Fully charged"),
        "pending-charge": qsTr("Waiting to charge"),
        "pending-discharge": qsTr("Waiting to discharge"),
        "charging": qsTr("Charging"), "discharging": qsTr("On battery"),
        "not-charging": qsTr("Plugged in")
    })
    readonly property var profiles: ({
        "power-saver": {label: qsTr("Power saver"), icon: "eco", tint: "#8da394"},
        "balanced": {label: qsTr("Balanced"), icon: "balance", tint: "#919faf"},
        "performance": {label: qsTr("Performance"), icon: "speed", tint: "#b0a18a"}
    })
    readonly property var actionIcons: ({trickle_charge: "battery_charging_full", amdgpu_panel_power: "monitor", amdgpu_dpm: "memory"})
    readonly property var actionNames: ({trickle_charge: qsTr("Trickle Charge"), amdgpu_panel_power: qsTr("Amdgpu Panel Power"), amdgpu_dpm: qsTr("Amdgpu Dpm")})
    readonly property var automationMessages: ({
        paused: qsTr("Automatic switching paused · manual profile selected"),
        active: qsTr("%1 · requesting %2"), "keep-current": qsTr("%1 · keep current profile"),
        blocked: qsTr("Waiting for another application's profile request to finish"),
        unavailable: qsTr("Automatic switching unavailable · battery or configured profile is unavailable"),
        error: qsTr("Automatic switching failed · %3"),
        waiting: qsTr("Automatic switching ready · waiting for a battery level")
    })
    readonly property var calibrationMessages: ({
        discharging: qsTr("Calibration: force-discharging to 1%"),
        charging: qsTr("Calibration: charging fully before restoring thresholds")
    })
    readonly property var suspendActions: ({lock: qsTr("Lock"), suspend: qsTr("Suspend"), hibernate: qsTr("Hibernate")})
    readonly property var suspendCapabilities: ({
        yes: qsTr("Available · locks before %1"),
        challenge: qsTr("Authorisation required · configure system policy before %1"),
        inhibited: qsTr("Temporarily blocked by an application’s suspend inhibitor"),
        "inhibitor-blocked": qsTr("Temporarily blocked by an application’s suspend inhibitor"),
        "challenge-inhibitor-blocked": qsTr("Suspend is inhibited and also requires authorisation"),
        no: qsTr("Disabled or not permitted by system policy")
    })
    function lookup(map: var, key: string, fallback: var): var {
        return Object.prototype.hasOwnProperty.call(map, key) ? map[key] : fallback;
    }
}
