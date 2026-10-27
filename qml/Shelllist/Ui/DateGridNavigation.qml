import QtQuick

// A scoped surface-navigation region, never a field or global shortcut owner.
// Hosts supply civil dates; no event membership or ordering is inferred here.
FocusScope {
    id: region
    property string dateKey: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property bool blocked: false
    signal chosen(string dateKey)
    signal moved(string dateKey)

    function civil(key: string): date {
        const parts = key.split("-");
        return new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), 12));
    }
    function key(value: date): string {
        return value.getUTCFullYear().toString().padStart(4, "0") + "-"
            + String(value.getUTCMonth() + 1).padStart(2, "0") + "-"
            + value.getUTCDate().toString().padStart(2, "0");
    }
    function move(days: int, months: int): void {
        if (blocked) return;
        const value = civil(dateKey);
        if (months) {
            const day = value.getUTCDate();
            value.setUTCDate(1);
            value.setUTCMonth(value.getUTCMonth() + months);
            const last = new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth() + 1, 0)).getUTCDate();
            value.setUTCDate(Math.min(day, last));
        } else value.setUTCDate(value.getUTCDate() + days);
        moved(key(value));
    }
    function choose(value: string): void {
        if (blocked) return;
        forceActiveFocus(Qt.OtherFocusReason);
        chosen(value);
    }
    function focusContent(): void { if (!blocked) forceActiveFocus(Qt.OtherFocusReason); }
    Keys.onPressed: function(event) {
        if (blocked || event.modifiers !== Qt.NoModifier) return;
        if (event.key === Qt.Key_Left) move(-1, 0);
        else if (event.key === Qt.Key_Right) move(1, 0);
        else if (event.key === Qt.Key_Up) move(-7, 0);
        else if (event.key === Qt.Key_Down) move(7, 0);
        else if (event.key === Qt.Key_PageUp) move(0, -1);
        else if (event.key === Qt.Key_PageDown) move(0, 1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat) chosen(dateKey);
        } else return;
        event.accepted = true;
    }
}
