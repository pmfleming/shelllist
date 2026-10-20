pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Bar as Bar

TestCase {
    id: testCase
    name: "MaterialBar"
    when: windowShown
    visible: true
    width: 1200
    height: 70
    Component {
        id: barFactory
        Bar.BarContent {
            height: 51
            screenName: "test"
            controller: Bar.BarController {
                surfaceRegistry: null
                backend.active: false
                battery: ({available: true, percentage: 80})
                notifications: ({count: 17, dnd: false})
            }
        }
    }
    function init(): void { failOnWarning(/.*/); }
    function test_updateFailuresRemainVisibleAndRecoverWithoutMutation(): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: 700});
        const controller = bar.controller;
        const module = function () { return controller.statusModules(new Date()).find(item => item.id === "updates"); };
        controller.updates = {available: true, jobs: [{name: "ai-tools", status: "failed", phase: "blocked", error: "t3: packaging failure; build suppressed"}]};
        verify(module().visible);
        compare(module().tone, "danger");
        verify(module().tooltip.includes("t3: packaging failure"));
        compare(module().primary, "updates");
        controller.updates = {available: true, jobs: [{name: "system", status: "interrupted", error: "worker stopped"}]};
        compare(module().tone, "danger");
        controller.updates = {available: true, jobs: [{name: "ai-tools", status: "completed", phase: "current"}]};
        verify(!module().visible);
        controller.updates = {available: true, ready: true, jobs: []};
        verify(module().visible);
        verify(module().tooltip.includes("ready"));
        controller.updates = {available: true, error: "malformed status", jobs: []};
        compare(module().tone, "danger");
    }
    function test_unknownRoutesCannotCallObjectPrototypeMethods(): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: 700});
        for (const name of ["missing", "__proto__", "constructor", "toString"])
            verify(!bar.controller.triggerModuleAction(name));
    }
}
