import QtQuick
import QtTest
import "../../qml/Shelllist/Io/HyprlandWorkspaceRules.js" as Rules

TestCase {
    name: "WorkspaceRules"

    function monitors(): var {
        return [
            {
                id: 0,
                name: "main",
                x: 0,
                y: 0,
                width: 1000,
                height: 800,
                scale: 1,
                focused: true
            },
            {
                id: 1,
                name: "right",
                x: 1000,
                y: 0,
                width: 1000,
                height: 800,
                scale: 1,
                description: "Acme Display",
                make: "Acme",
                model: "Panel",
                serial: "123"
            },
            {
                id: 2,
                name: "left",
                x: -1000,
                y: 0,
                width: 1000,
                height: 800,
                scale: 1
            }
        ];
    }

    function test_monitorSelectors(): void {
        const screens = monitors();
        compare(Rules.directionalMonitor("r", screens).name, "right");
        compare(Rules.directionalMonitor("l", screens).name, "left");
        verify(Rules.monitorMatches("+1", screens[1], screens));
        verify(Rules.monitorMatches("-1", screens[2], screens));
        verify(Rules.monitorMatches("+4", screens[1], screens));
        verify(Rules.monitorMatches("desc:Acme", screens[1], screens));
        verify(Rules.monitorMatches("desc:Acme Panel", screens[1], screens));
        screens[1].x = 1002;
        compare(Rules.directionalMonitor("r", screens), null);
        screens[1].x = 1001;
        compare(Rules.directionalMonitor("r", screens).name, "right");
    }

    function test_windowFiltersAndGroups(): void {
        const workspace = {
            id: 1,
            windows: 8
        };
        const clients = [
            {
                workspace: {
                    id: 1
                },
                mapped: true,
                floating: false,
                grouped: ["b", "a"]
            },
            {
                workspace: {
                    id: 1
                },
                mapped: true,
                floating: false,
                grouped: ["a", "b"]
            },
            {
                workspace: {
                    id: 1
                },
                mapped: true,
                floating: true,
                pinned: true,
                visible: false
            },
            {
                workspace: {
                    id: 2
                },
                mapped: true,
                floating: false
            }
        ];
        compare(Rules.windowCount("", workspace, clients), 8);
        compare(Rules.windowCount("t", workspace, clients), 2);
        compare(Rules.windowCount("tg", workspace, clients), 1);
        compare(Rules.windowCount("f", workspace, clients), 1);
        compare(Rules.windowCount("fv", workspace, clients), 0);
        compare(Rules.windowCount("p", workspace, clients), 1);
    }

    function test_combinedSelectors(): void {
        const screens = monitors();
        const workspace = {
            id: 3,
            name: "web",
            windows: 2,
            hasfullscreen: false
        };
        const snapshot = {
            monitors: screens,
            clients: []
        };
        verify(Rules.workspaceMatches("r[1-4] m[current] w[2] f[-1]", workspace, screens[0], snapshot));
        verify(!Rules.workspaceMatches("r[1-4] m[right]", workspace, screens[0], snapshot));
        verify(!Rules.workspaceMatches("r[1-4] junk", workspace, screens[0], snapshot));
        verify(!Rules.workspaceMatches("w[bad]", workspace, screens[0], snapshot));
        verify(Rules.workspaceMatches("name:web", workspace, screens[0], snapshot));
    }
}
