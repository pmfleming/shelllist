pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Core as Core

TestCase {
    id: testCase
    name: "KeyedUpdates"
    when: windowShown
    visible: true
    width: 400
    height: 100

    Component {
        id: fixture
        Item {
            id: host
            property alias model: keyed
            property alias rows: rows
            property int creations: 0
            property int removals: 0
            Core.KeyedListModel { id: keyed }
            Repeater {
                id: rows
                model: keyed
                // Native editors expose delegate destruction and lost draft/focus.
                TextInput {
                    required property string resultKey
                    required property var resultData
                    text: "saved"
                    Component.onCompleted: host.creations++
                    Component.onDestruction: if (host) host.removals++
                }
            }
        }
    }
    function values(prefix, count) {
        return Array.from({length: count}, (_, i) => ({key: prefix + i, title: "Row " + i}));
    }
    function make() {
        const host = createTemporaryObject(fixture, testCase);
        host.model.values = values("old", 80);
        compare(host.model.count, 80);
        return host;
    }
    function init() { failOnWarning(/.*/); }
    function test_prependAndMiddleRemovalPreserveDelegateAndNativeDraft() {
        const host = make();
        const editor = host.rows.itemAt(70);
        editor.forceActiveFocus();
        keyClick(Qt.Key_End); keyClick(Qt.Key_X);
        compare(editor.text, "savedx");
        const next = values("new", 40).concat(host.model.values);
        next[110] = {key: "old70", title: "Updated without replacing editor"};
        host.model.values = next;
        compare(host.rows.itemAt(110), editor, "large index shifts are not reorders or resets");
        compare(host.creations, 120, "only the 40 genuinely new delegates are created");
        compare(host.removals, 0);
        compare(editor.resultData.title, "Updated without replacing editor");
        verify(editor.activeFocus); compare(editor.text, "savedx");
        host.model.values = next.slice(0, 10).concat(next.slice(60));
        compare(host.rows.itemAt(60), editor);
        compare(host.creations, 120);
        compare(host.removals, 50, "only removed keys lose their delegates");        verify(editor.activeFocus); compare(editor.text, "savedx");
    }
    function test_supersededInsertionCannotAppendStaleChunks() {
        const host = make();
        const editor = host.rows.itemAt(0);
        const original = host.model.values;
        host.model.maximumSynchronousItems = 8;
        host.model.chunkSize = 4;
        host.model.values = values("new", 40).concat(original);
        compare(host.model.count, 84, "insertion yields after its first bounded chunk");
        compare(host.rows.itemAt(4), editor);
        host.model.values = original;
        compare(host.rows.itemAt(0), editor);
        wait(30);
        compare(host.model.count, 80);
        compare(host.model.get(0).resultKey, "old0");
        host.model.values = original.concat(values("tail", 40));
        tryCompare(host.model, "count", 120);
        compare(host.rows.itemAt(0), editor, "append-only paging still retains existing delegates");
    }
}
