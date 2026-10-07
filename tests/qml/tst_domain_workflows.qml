pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Activity as Activity

DaemonTestCase {
    id: testCase
    name: "DomainWorkflows"
    when: windowShown
    visible: true
    width: 1100
    height: 650
    Component {
        id: panelFactory
        Ui.PanelSurface {
            chooserController: Ui.ChooserController {
                id: owner
                uiActive: true
                viewMemory: Ui.ChooserMemory {
                    controller: owner
                    key: "settings::test"
                    tab: "settings"
                    tabs: ["settings"]
                    presentationOpen: true
                }
            }
            Ui.DetailFlickable {
                anchors.fill: parent
                viewMemory: owner.viewMemory
                memoryTab: "settings"
                Ui.TextField { objectName: "ordinary"; width: parent.width; text: "ordinary value" }
            }
        }
    }
    Component { id: activityFactory; Activity.ActivityController { rangeQueriesEnabled: false } }
    function test_activityUpdatesOnlyItsSubscribedDomainsAndRecoversGaps() {
        const owner = createTemporaryObject(activityFactory, testCase);
        compare(Array.from(owner.backend.streams), ["activity.changed", "timezone.changed"]);
        verify(owner.notificationState === undefined, "Activity does not construct a second notification owner");
        const activity = {available: true, event_count: 7};
        const timezone = {timezone: "Europe/Amsterdam", utc_offset_seconds: 7200};
        owner.backend.acceptSharedEvent({protocol: "bar-api", version: 1, stream: "activity.changed", event: "changed", data: activity});
        compare(owner.activity, activity);
        owner.backend.acceptSharedEvent({protocol: "bar-api", version: 1, stream: "timezone.changed", event: "subscribed", data: timezone});
        compare(owner.timezone, timezone);
        for (const event of [{stream: "notifications.changed", event: "changed"}, {stream: "activity.changed", event: "progress"}])
            owner.backend.acceptSharedEvent(Object.assign({protocol: "bar-api", version: 1, data: {available: false}}, event));
        compare(owner.activity, activity);
        owner.backend.acceptSharedResponse("activity-snapshot", {protocol: "bar-api", version: 1, ok: true, data: {snapshot: {activity, timezone}}}, "");
        const before = calls.length;
        owner.backend.acceptSharedEvent({protocol: "bar-api", version: 1, stream: "activity.changed", event: "lagged"});
        compare(calls.length, before + 1);
        compare(calls[calls.length - 1].method, "bar.snapshot");
    }
    function init() { failOnWarning(/.*/); }
    Component {
        id: iconActionFactory
        Ui.ActionButton { label: "Settings"; icon: "󰒓"; width: 42; height: 42 }
    }
    function test_revealedSensitiveFieldsNeverHaveRestorableLocations() {
        const panel = createTemporaryObject(panelFactory, testCase);
        const field = findChild(panel, "ordinary");
        compare(Ui.FocusLocations.key(null), "");
        compare(Ui.FocusLocations.uniqueTarget([field], field.focusKey), field);
        const duplicate = createTemporaryObject(iconActionFactory, panel, {objectName: field.objectName, enabled: false});
        compare(Ui.FocusLocations.uniqueTarget([field, duplicate], field.focusKey), null);
        field.sensitive = true;
        field.password = false;
        compare(Ui.FocusLocations.uniqueTarget([field], field.focusKey), null);
        field.focusInput(false);
        compare(field.selectionState(), null);
        compare(Ui.FocusLocations.capture(panel, findChild(field, "fieldInput")), null);
        panel.detailsNavigation.currentTarget = field;
        compare(panel.detailsNavigation.locationState().target, "");
    }
}
