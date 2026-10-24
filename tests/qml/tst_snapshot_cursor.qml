import QtQuick
import QtTest
import Shelllist.Io as Io

TestCase {
    id: tests
    name: "SnapshotCursor"
    Component { id: factory; Io.SnapshotCursor {} }
    function stamp(epoch, revision, previous) {
        const result = {epoch: epoch, revision: revision};
        if (previous !== undefined)
            result.previous_epoch = previous;
        return result;
    }
    function test_fullReplacementsSkipRevisionsButNeverRegress() {
        const cursor = createTemporaryObject(factory, tests);
        let published = 0;
        const publish = function() { published++; };
        verify(cursor.accept(stamp("a", 2), publish));
        verify(cursor.accept(stamp("a", 9), publish));
        verify(!cursor.accept(stamp("a", 2), publish));
        verify(!cursor.accept(stamp("a", 9), publish));
        verify(!cursor.accept(stamp("unknown", 10), publish));
        compare(published, 2);
        compare(cursor.revision, 9);
        // A coalesced rollover need not deliver the old maximum or new revision 1.
        verify(cursor.accept(stamp("b", 3, "a"), publish));
        verify(!cursor.accept(stamp("a", cursor.maximumRevision), publish));
        compare(cursor.epoch, "b");
        compare(published, 3);
        cursor.reset(); // only the owner retires the transport generation
        verify(cursor.accept(stamp("fresh", 1), publish));
    }
    function test_malformedWatermarks_data() {
        return [null, {}, [], stamp("", 1), stamp("a", 0), stamp("a", -1),
            stamp("a", 1.5), stamp("a", "2"), stamp("a", 9007199254740992),
            stamp("a", NaN), stamp("a", Infinity), stamp("a", 2, "a"),
            stamp("a", 2, 42)].map((value, index) => ({tag: String(index), value: value}));
    }
    function test_malformedWatermarks(data) {
        const cursor = createTemporaryObject(factory, tests);
        verify(cursor.accept(stamp("a", 1), function() {}));
        verify(!cursor.accept(data.value, function() { fail("must not publish malformed state"); }));
        compare(cursor.revision, 1);
        verify(cursor.error.length > 0);
    }
    function test_failedPayloadPublicationCannotConsumeRevision() {
        const cursor = createTemporaryObject(factory, tests);
        let failed = false;
        try {
            cursor.accept(stamp("a", 1), function() { throw new Error("Malformed payload"); });
        } catch (error) {
            failed = true;
        }
        verify(failed);
        compare(cursor.epoch, "");
        compare(cursor.revision, 0);
        verify(cursor.accept(stamp("a", 1), function() {}));
    }
}
