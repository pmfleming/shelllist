.pragma library

function escapeHtml(value) {
    return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function escapeRegExp(value) {
    return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function hotkeyStartIndex(label, key) {
    const match = new RegExp("(^|[ -])" + escapeRegExp(key)).exec(label);
    return match ? match.index + match[1].length : label.indexOf(key);
}

function highlightHotkey(text, hotkey) {
    const labelText = String(text);
    const keyText = String(hotkey);
    if (keyText.length === 0)
        return escapeHtml(labelText);
    const index = hotkeyStartIndex(labelText.toLowerCase(), keyText.charAt(0).toLowerCase());
    if (index < 0)
        return escapeHtml(labelText);
    return escapeHtml(labelText.slice(0, index))
        + "<u><b>" + escapeHtml(labelText.charAt(index)) + "</b></u>"
        + escapeHtml(labelText.slice(index + 1));
}
