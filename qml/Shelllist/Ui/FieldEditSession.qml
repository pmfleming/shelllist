import QtQuick

// Transient field-local transaction. Never put drafts in chooser/session memory.
// Domains receive publishRequested only on save, or on explicit live rollback.
QtObject {
    id: session
    required property Item owner
    property var value
    property var initialValue: value
    property bool livePreview: false
    property bool active: false
    property bool finishing: false
    property var originalValue: null
    property var bindingValue: null
    // Hold the source binding aside for the entire edit, including native
    // changes and imperative rollback/Home/End writes. Restore only a binding:
    // an unbound input must retain its saved draft (or its discarded original).
    property string valueProperty: ""
    readonly property Binding valueBinding: Binding {
        target: session.valueProperty.length > 0 ? session.owner : null
        property: session.valueProperty
        value: session.bindingValue
        when: session.active && session.valueProperty.length > 0
        restoreMode: Binding.RestoreBinding
    }
    readonly property DetailsNavigation navigation: findNavigation(owner.parent)
    property bool focused: owner.activeFocus
    // Native focus can arrive before an asynchronous page is discovered by the
    // navigation scope. Capture first, so its first keystroke cannot leak a write.
    onFocusedChanged: if (focused && navigation && navigation.available(owner)) begin()

    signal restoreRequested(var value)
    signal publishRequested(var value)
    signal finished(bool saved)

    function findNavigation(item: Item): DetailsNavigation {
        while (item) {
            if (item instanceof ModalFrame)
                return null;
            if (item instanceof DetailsNavigation)
                return item as DetailsNavigation;
            item = item.parent;
        }
        return null;
    }
    function begin(): void {
        if (active || finishing)
            return;
        originalValue = initialValue;
        bindingValue = originalValue;
        active = true;
    }
    function finish(save: bool): void {
        if (!active || finishing)
            return;
        finishing = true;
        const changed = value !== originalValue;
        // Binding restores its predecessor only if the target still holds
        // its last applied value. Native edits can change that value without
        // updating Binding, so synchronize it before releasing the override.
        if (save)
            bindingValue = value;
        if (!save)
            restoreRequested(originalValue);
        if (changed && ((save && !livePreview) || (!save && livePreview)))
            publishRequested(value);
        finished(save);
        active = false;
        originalValue = null;
        bindingValue = null;
        finishing = false;
    }
}
