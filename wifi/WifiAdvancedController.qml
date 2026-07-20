import QtQuick

Item {
    required property WifiController controller
    required property WifiBackend backend

    property bool open: false
    property string section: "security"
    property string profilePath: ""
    property var profile: ({})
    property string secret: ""
    property string error: ""
    property string saveOrigin: ""
    readonly property bool loading: backend.isPending("advanced-load")
    readonly property bool saving: backend.isPending("advanced-save")
    readonly property bool secretLoading: backend.isPending("advanced-secret")

    signal sectionTransitionRequested(string section, bool animate)

    function reset() { profilePath = ""; profile = ({}); secret = ""; error = ""; }
    function openSettings(nextSection) {
        const savedProfile = controller.profileFor(controller.detailAp);
        if (!savedProfile) { controller.status = "Connect to this network before editing saved settings."; return; }
        controller.detailsOpen = true;
        controller.detailsExpansionProgress = 1;
        controller.windowPlacementRequested();
        const targetSection = nextSection === "hardware" ? "hardware" : "security";
        sectionTransitionRequested(targetSection, open && targetSection !== section);
        section = targetSection;
        if (open && profilePath === (savedProfile.path || "")) return;
        open = true; reset(); profilePath = savedProfile.path || "";
        if (!backend.loadAdvancedProfile(profilePath)) error = "Saved profile details are already loading.";
    }
    function closeSettings() {
        if (open) controller.advancedSectionLeaving(section);
        open = false; reset();
    }
    function selectSection(nextSection) {
        if (open && nextSection !== section) controller.advancedSectionLeaving(section);
        openSettings(nextSection);
    }
    function applyProfile(value) {
        if (!open || (value.path || "") !== profilePath) return;
        profile = value; error = "";
    }
    function save(settings, origin) {
        if (!open || profilePath.length === 0 || saving) return false;
        error = ""; saveOrigin = origin || section;
        if (backend.saveAdvancedProfile(profilePath, settings)) return true;
        saveOrigin = ""; error = "Advanced profile settings are already being saved."; return false;
    }
    function applySave(result) {
        const origin = saveOrigin;
        saveOrigin = ""; controller.status = result.message || "Saved advanced Wi-Fi settings"; secret = "";
        if (open && profilePath.length > 0 && section === origin) backend.loadAdvancedProfile(profilePath);
    }
    function revealSecret() {
        if (!open || profilePath.length === 0 || secretLoading) return;
        error = ""; backend.revealAdvancedSecret(profilePath);
    }
    function applySecret(result) {
        if (!open || (result.path || "") !== profilePath) return;
        secret = result.available ? (result.password || "") : "";
        error = result.available ? "" : "The saved Wi-Fi password is not readable.";
    }
    function handlesCall(id) { return id === "advanced-load" || id === "advanced-save" || id === "advanced-secret"; }
    function failCall(id, message) {
        if (!handlesCall(id)) return false;
        error = message;
        if (id === "advanced-save") saveOrigin = "";
        return true;
    }
    function selectionChanged() {
        const savedProfile = controller.profileFor(controller.detailAp);
        if (open && (!savedProfile || (savedProfile.path || "") !== profilePath)) closeSettings();
    }
}
