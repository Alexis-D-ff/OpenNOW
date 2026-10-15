import QtQuick
import OpenNOW

Text {
    readonly property var updater: ShellStore.updaterState || ({})
    readonly property string attention: ShellStore.updaterAttention
    text: attention === "available" ? qsTr("Update available")
        : attention === "downloading" ? qsTr("Downloading update")
        : attention === "ready" ? qsTr("Ready to restart")
        : attention === "installing" ? qsTr("Installing update")
        : attention === "error" ? (updater.status === "error" ? qsTr("Couldn't check for updates") : qsTr("Update failed"))
        : updater.status === "checking" ? qsTr("Checking for updates")
        : updater.status === "not-available" && updater.lastCheckedAt ? qsTr("You're up to date")
        : qsTr("OpenNOW updates")
    color: Theme.label
    font.family: Theme.displayFont
    font.weight: Font.Black
    elide: Text.ElideRight
}
