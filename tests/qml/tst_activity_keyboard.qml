import QtQuick
import QtTest
import Shelllist.Activity as Activity
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "ActivityKeyboard"
    when: windowShown
    width: 500
    height: 400
    visible: true

    Component {
        id: controllerComponent
        Activity.ActivityController {
            property var toggledIds: []
            property var deletedIds: []
            rangeQueriesEnabled: false
            function toggleTodo(todo: var): bool {
                toggledIds = toggledIds.concat([todo.id]);
                return true;
            }
            function deleteTodo(todo: var): bool {
                deletedIds = deletedIds.concat([todo.id]);
                return true;
            }
        }
    }

    Component {
        id: headerComponent
        Ui.ChooserHeader {
            uiScale: 1
            powerAccessory: Component { Item { implicitWidth: 27 } }
        }
    }

    Component {
        id: actionComponent
        Ui.ActionArea {
            width: 120
            height: 40
            accessibleName: "Open weather"
            property int activations: 0
            onClicked: activations += 1
        }
    }

    Component {
        id: textComponent
        Ui.ThemeText { text: "Weather" }
    }

    function test_sharedActionAreaAndTypography(): void {
        const area = createTemporaryObject(actionComponent, testCase);
        area.forceActiveFocus();
        tryCompare(area, "activeFocus", true);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Enter);
        keyClick(Qt.Key_Space);
        compare(area.activations, 3);
        area.enabled = false;
        area.activate();
        compare(area.activations, 3);
        const text = createTemporaryObject(textComponent, testCase);
        compare(text.font.family, Ui.Theme.fontFamily);
        compare(text.font.pixelSize, Ui.Theme.fontSizeBody);
        compare(text.color, Ui.Theme.text);
    }

    function test_accessoryLoaderAcceptsVisualItems(): void {
        const header = createTemporaryObject(headerComponent, testCase, { width: 480 });
        verify(header !== null);
        wait(10);
    }

    function test_todoActionsSupportKeyboard(): void {
        const controller = createTemporaryObject(controllerComponent, testCase);
        controller.todos = [{ id: "one", title: "Review quality", completed: false,
            due_date: controller.selectedDateKey }];
        const component = Qt.createComponent("../../qml/Shelllist/Activity/ActivityTodoSection.qml");
        compare(component.status, Component.Ready, component.errorString());
        const section = createTemporaryObject(component, testCase, { controller: controller, uiScale: 1 });
        verify(section !== null);
        let toggle = null;
        tryVerify(function () { toggle = findChild(section, "todoToggle"); return toggle !== null; });
        toggle.forceActiveFocus();
        tryCompare(toggle, "activeFocus", true);
        keyClick(Qt.Key_Space);
        compare(controller.toggledIds.length, 1);
        compare(controller.toggledIds[0], "one");
        const remove = findChild(section, "todoDelete");
        verify(remove !== null);
        remove.forceActiveFocus();
        tryCompare(remove, "activeFocus", true);
        keyClick(Qt.Key_Return);
        compare(controller.deletedIds.length, 1);
        compare(controller.deletedIds[0], "one");
        section.destroy();
        wait(0);
    }
}
