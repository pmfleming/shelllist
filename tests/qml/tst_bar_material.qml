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
    function test_updateOutcomesDoNotCreateAStandaloneBarIcon(): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: 700});
        for (const state of [
            {available: true, ready: true, jobs: []},
            {available: true, jobs: [{name: "system", status: "running"}]},
            {available: true, error: "malformed status", jobs: []},
            {available: true, jobs: [{name: "ai-tools", status: "failed", error: "build failed"}]}
        ]) {
            bar.controller.updates = state;
            verify(!bar.controller.statusModules(new Date()).some(item => item.id === "updates"));
            compare(bar.controller.updates, state); // Presentation cannot clear backend outcomes.
        }
    }
    function test_unknownRoutesCannotCallObjectPrototypeMethods(): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: 700});
        for (const name of ["missing", "__proto__", "constructor", "toString"])
            verify(!bar.controller.triggerModuleAction(name));
    }
}
