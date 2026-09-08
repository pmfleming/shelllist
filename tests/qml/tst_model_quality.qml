import QtQuick
import QtTest
import "../../qml/Shelllist/Core/Model.js" as Model

TestCase {
    name: "ModelQuality"

    function result(id: string, title: string, score: real): var {
        return Model.result({ providerId: "apps", id: id, title: title, score: score });
    }

    function test_uniqueValuesKeepOrderAndRejectDuplicates(): void {
        compare(Model.stringList([" utility ", "__proto__", "utility", "constructor", ""]),
            ["utility", "__proto__", "constructor"]);
        const values = Array.from({ length: 2000 }, function (_, index) {
            return { providerId: "apps", id: String(index), title: "App " + index };
        });
        compare(Model.resultList(values).length, 2000);
        values.push(values[0]);
        let error = "";
        try { Model.resultList(values); } catch (failure) { error = String(failure); }
        verify(error.indexOf("duplicate key") >= 0);
    }

    function test_rankingPreservesIdentityAndInputOrder(): void {
        const values = [result("b", "Beta", 1), result("a", "Alpha", 2)];
        const ranked = Model.rankResults(values, "  ");
        verify(ranked[0] === values[1]);
        compare(values[0].id, "b");
        compare(ranked.map(function (item) { return item.id; }), ["a", "b"]);
    }

    function test_preparedQueryMatchesIndividualScores(): void {
        const values = [result("cafe", "Café Terminal", 10), result("terminal", "Terminal 9", 5),
            result("other", "Calculator", 100)];
        for (const query of ["cafe", "TERMINAL 9", "terminal", "missing", ""]) {
            const expected = values.map(function (item) { return { item: item, matchScore: Model.matchScore(item, query) }; })
                .filter(function (entry) { return entry.matchScore >= 0; })
                .sort(Model.compareRanked).map(function (entry) { return entry.item.id; });
            compare(Model.rankResults(values, query).map(function (item) { return item.id; }), expected);
        }
    }
}
