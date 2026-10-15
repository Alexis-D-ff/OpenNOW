import QtQuick
import QtQuick.Controls
import OpenNOW

// The next updater action, shared by Settings › Updates and the status-bar
// panel. Installing always goes through the Qt confirmation below.
DesktopSettingsButton {
    id: root
    objectName: "updatePrimaryAction"
    readonly property var updater: ShellStore.updaterState || ({})
    // Settings › Updates adds a second, install-only action when a staged
    // package is older than the newly selected release.
    property bool installOnly: false
    // A newer selected release takes priority over an older staged package.
    readonly property string nextAction: installOnly ? "install"
        : updater.status === "downloading" ? "downloading"
        : updater.canDownload === true ? "download"
        : updater.canInstall === true ? "install" : "check"
    // The status-bar panel uses short labels; Settings › Updates spells them out.
    property bool panelLabels: false
    primary: !installOnly
    text: panelLabels ? (nextAction === "install" ? qsTr("Restart to install")
            : nextAction === "download" ? (ShellStore.updaterAttention === "error" ? qsTr("Retry") : qsTr("Download"))
            : nextAction === "downloading" ? qsTr("Downloading…")
            : ShellStore.updaterAttention === "error" ? qsTr("Retry")
            : updater.status === "checking" ? qsTr("Checking…") : qsTr("Check for updates"))
        : nextAction === "install" ? (updater.downloadedVersion
            ? qsTr("Install %1 and restart").arg(updater.downloadedVersion) : qsTr("Install and restart"))
        : nextAction === "download" ? qsTr("Download verified update")
        : nextAction === "downloading" ? qsTr("Downloading…")
        : updater.status === "checking" ? qsTr("Checking…") : qsTr("Check for updates")
    enabled: nextAction === "install" ? ShellStore.updaterCanInstall
        : nextAction === "download" ? !ShellStore.updaterBusy
        : nextAction === "check" && !ShellStore.updaterBusy && updater.canCheck === true
    onClicked: {
        if (nextAction === "install")
            installConfirmation.open()
        else if (nextAction === "download")
            ShellStore.downloadUpdate()
        else
            ShellStore.checkForUpdates()
    }

    Dialog {
        id: installConfirmation
        objectName: "updateInstallConfirmation"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 440)
        // Bound the dialog independently of the style's header/footer sizing.
        implicitHeight: DesktopTokens.px(220)
        height: Math.min(parent.height - 48, implicitHeight)
        modal: true
        focus: true
        title: root.updater.downloadedVersion ? qsTr("Install %1 and restart").arg(root.updater.downloadedVersion) : qsTr("Install and restart")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: ShellStore.installUpdate(true)
        contentItem: Label {
            wrapMode: Text.WordWrap
            text: qsTr("OpenNOW will prepare the verified update, close, replace this installation, and restart. Continue?")
        }
    }
}
