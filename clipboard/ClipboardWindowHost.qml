import Shelllist.Ui as Ui

Ui.PopupWindowHost {
    modeEnvironment: "SHELLLIST_CLIPBOARD_MODE"
    ipcTarget: "clipboard"
    shortcutName: "clipboard"
    shortcutDescription: "Toggle the Shelllist clipboard history"
    windowTitle: "Shelllist Clipboard"
    layerNamespace: "shelllist-clipboard"
}
