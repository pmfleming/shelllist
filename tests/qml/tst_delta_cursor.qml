import QtQuick
import QtTest
import Shelllist.Io as Io

TestCase {
    id: tests
    name: "DeltaCursor"
    when: windowShown
    Component { id: factory; Io.DeltaCursor { property int gaps: 0; onGapDetected: gaps++ } }
    function record(epoch, base, initial) { return {epoch: epoch, base_revision: base, revision: base + 1, initial: initial}; }
    function test_chainDuplicatesGapAndAuthoritativeReplacement() {
        const cursor = createTemporaryObject(factory, tests);
        verify(cursor.accept("owned", record("epoch", 0, true)));
        verify(cursor.accept("owned", record("epoch", 1, false)));
        verify(!cursor.accept("owned", record("epoch", 0, true)));
        compare(cursor.revision, 2);
        verify(!cursor.accept("owned", record("epoch", 3, false)));
        compare(cursor.revision, 2);
        compare(cursor.gaps, 1);
        verify(!cursor.accept("owned", record("epoch", 2, false)), "reordered data cannot fill a retired generation");
        verify(!cursor.accept("owned", record("epoch", 0, true)));
        compare(cursor.gaps, 1);
        verify(cursor.accept("replacement", record("new-epoch", 0, true)));
        verify(!cursor.recovering);
        compare(cursor.revision, 1);
    }
    function test_missingBaselineAndMalformedCountersFailClosed_data() {
        return [null, {}, {epoch: "e", initial: true, base_revision: 0, revision: "1"},
            {epoch: "e", initial: true, base_revision: 0, revision: 1.5},
            {epoch: "e", initial: true, base_revision: -1, revision: 0},
            {epoch: "e", initial: false, base_revision: 9007199254740991, revision: 9007199254740992},
            record("e", 1, false), record("e", 1, true), record("e", 0, false),
            record("", 0, true)].map((value, index) => ({tag: String(index), value: value}));
    }
    function test_missingBaselineAndMalformedCountersFailClosed(data) {
        const cursor = createTemporaryObject(factory, tests);
        verify(!cursor.accept("owned", data.value));
        compare(cursor.revision, 0);
        compare(cursor.gaps, 1);
    }
    function test_epochChangesRequireNewOwnershipOrExactCounterExhaustion() {
        const cursor = createTemporaryObject(factory, tests);
        verify(cursor.accept("owned", record("epoch", 0, true)));
        verify(!cursor.accept("owned", record("unsolicited", 0, true)));
        compare(cursor.epoch, "epoch");
        cursor.reset();
        verify(cursor.accept("owned", record("epoch", 0, true)));
        cursor.revision = cursor.maximumRevision;
        verify(!cursor.accept("owned", record("rollover", 0, false)));
        compare(cursor.revision, cursor.maximumRevision);
        compare(cursor.epoch, "epoch");
        verify(!cursor.accept("owned", record("rollover", 0, true)), "recovery still requires replacement ownership");
        verify(cursor.accept("replacement", record("epoch", 0, true)));
        cursor.revision = cursor.maximumRevision;
        verify(cursor.accept("replacement", record("rollover", 0, true)));
        compare(cursor.revision, 1);
        verify(!cursor.accept("replacement", record("epoch", 0, true)));
        compare(cursor.epoch, "rollover");
    }
}
