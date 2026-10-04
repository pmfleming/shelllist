pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import "../../qml/Shelllist/Io/HyprlandSettings.js" as CompositorSettings

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
    function init() { failOnWarning(/.*/); }
    Component {
        id: iconActionFactory
        Ui.ActionButton { label: "Settings"; icon: "󰒓"; width: 42; height: 42 }
    }
    function test_compositorPreferenceAndScopedBlurCommand() {
        verify(CompositorSettings.motionDisabled({int: 0}));
        verify(!CompositorSettings.motionDisabled({int: 1}));
        const command = CompositorSettings.layerStyle("shelllist.test", true, true);
        compare(command[0], "hyprctl");
        compare(command[1], "eval");
        verify(command[2].includes("blur = true"));
        verify(command[2].includes("no_anim = true"));
        verify(command[2].includes("ignore_alpha = 0.01"));
        verify(command[2].includes("^shelllist\\\\.test$"), "scope is a literal namespace, not an arbitrary regex");
    }
    function test_panelRestoresEditorButNeverItsValue() {
        const panel = createTemporaryObject(panelFactory, testCase);
        const owner = panel.chooserController;
        owner.restoreUiFocus();
        tryVerify(() => panel.detailsNavigation.browsing);
        keyClick(Qt.Key_Return);
        const field = findChild(panel, "ordinary");
        tryVerify(() => field.inputActiveFocus);
        field.restoreSelection({anchor: 8, cursor: 2});
        owner.deactivateUi();
        panel.forceActiveFocus();
        field.text = "short";
        owner.activateUi("");
        owner.restoreUiFocus();
        tryVerify(() => field.inputActiveFocus);
        compare(field.text, "short");
        compare(field.selectionState().cursor, 2);
        compare(field.selectionState().anchor, 5);
        verify(!JSON.stringify(owner.focusMemory).includes("ordinary value"));
        keyClick(Qt.Key_Escape);
        verify(panel.detailsNavigation.browsing);
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
