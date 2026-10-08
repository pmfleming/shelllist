import QtQuick

// Dropdowns and segments share a local choice draft, not their owner's binding.
// Native activation outside a panel remains immediate; panel saves use finish().
FieldEditSession {
    required property string sourceValue
    readonly property string displayedValue: active ? value : sourceValue
    initialValue: sourceValue
    value: ""
    onActiveChanged: if (active) value = sourceValue
    onRestoreRequested: function (original) { value = original; }

    function choose(nextValue: string): void {
        if (active)
            value = nextValue;
        else if (nextValue !== sourceValue)
            publishRequested(nextValue);
    }
}
