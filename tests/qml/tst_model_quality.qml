import QtQuick
import QtTest
import "../../qml/Shelllist/Core/Model.js" as Model

TestCase {
    name: "ModelQuality"

    function test_uniqueValuesKeepOrderAndRejectDuplicates(): void {
        compare(Model.stringList([" utility ", "__proto__", "utility", "constructor", ""]), ["utility", "__proto__", "constructor"]);
        const values = Array.from({
            length: 2000
        }, function (_, index) {
            return {
                providerId: "apps",
                id: String(index),
                title: "App " + index
            };
        });
        compare(Model.resultList(values).length, 2000);
        values.push(values[0]);
        let error = "";
        try {
            Model.resultList(values);
        } catch (failure) {
            error = String(failure);
        }
        verify(error.indexOf("duplicate key") >= 0);
    }

}
