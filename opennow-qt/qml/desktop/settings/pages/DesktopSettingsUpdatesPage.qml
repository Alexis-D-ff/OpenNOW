import QtQuick
import QtQuick.Controls
import OpenNOW

// Settings › Updates is the single home for every updater control. The
// status-bar chip and its panel drive the same ShellStore updater state.
Column {
    id: page
    objectName: "desktopUpdatesSettings"
    required property real availableWidth
    required property var settingsScreen
    readonly property var updater: ShellStore.updaterState || ({})
    readonly property string channel: page.settingsScreen.valueSetting("updateChannel", "stable") === "nightly" ? qsTr("NIGHTLY") : qsTr("STABLE")
    readonly property string versionLine: page.updater.availableVersion && page.updater.availableVersion !== page.updater.currentVersion
        ? qsTr("%1  →  %2 · %3").arg(page.updater.currentVersion || Qt.application.version).arg(page.updater.availableVersion).arg(page.channel)
        : qsTr("%1 · %2").arg(page.updater.currentVersion || Qt.application.version).arg(page.channel)

    width: page.availableWidth
    spacing: DesktopTokens.px(12)
    Component.onCompleted: ShellStore.acknowledgeUpdateHighlights()

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        Item {
            width: parent.width
            implicitHeight: status.implicitHeight + DesktopTokens.px(48)
            Rectangle {
                id: markTile
                x: DesktopTokens.px(24); y: DesktopTokens.px(24)
                width: DesktopTokens.px(64); height: width; radius: DesktopTokens.px(16)
                color: DesktopTokens.raised
                Image {
                    anchors.centerIn: parent
                    width: DesktopTokens.px(38); height: DesktopTokens.px(22)
                    source: "qrc:/qt/qml/OpenNOW/res/brand/opennow-mark.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }
            Column {
                id: status
                x: markTile.x + markTile.width + DesktopTokens.px(20)
                y: DesktopTokens.px(24)
                width: parent.width - x - DesktopTokens.px(24)
                spacing: DesktopTokens.px(12)
                Row {
                    width: parent.width
                    spacing: DesktopTokens.px(12)
                    DesktopUpdateHeadline {
                        objectName: "updatesPageHeadline"
                        width: Math.min(implicitWidth, parent.width - (stateChip.visible ? stateChip.width + parent.spacing : 0))
                        font.pixelSize: DesktopTokens.px(26)
                    }
                    DesktopUpdateChip {
                        id: stateChip
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: false
                    }
                }
                Text {
                    width: parent.width
                    text: page.versionLine
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.px(12)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                    elide: Text.ElideRight
                }
                DesktopUpdateProgress { width: parent.width }
                Text {
                    width: parent.width
                    text: ShellStore.updaterError || page.updater.message || qsTr("Check GitHub Releases for a newer OpenNOW build.")
                    textFormat: Text.PlainText
                    color: Theme.label
                    font.family: Theme.bodyFont
                    font.pixelSize: DesktopTokens.px(14)
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Text {
                    width: parent.width
                    visible: !ShellStore.updaterSessionSafe
                    text: qsTr("End your streaming session before installing an update. Background updates will wait.")
                    color: Theme.textMuted
                    font.family: Theme.bodyFont
                    font.pixelSize: DesktopTokens.px(13)
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Flow {
                    width: parent.width
                    spacing: DesktopTokens.px(10)
                    DesktopUpdatePrimaryAction { id: primaryAction }
                    DesktopUpdatePrimaryAction {
                        objectName: "updatesPageInstallStaged"
                        installOnly: true
                        visible: primaryAction.nextAction === "download" && page.updater.canInstall === true
                    }
                    DesktopSettingsButton {
                        objectName: "updatesPageCheck"
                        visible: primaryAction.nextAction !== "check"
                        text: page.updater.status === "checking" ? qsTr("Checking…") : qsTr("Check for updates")
                        enabled: !ShellStore.updaterBusy && page.updater.canCheck === true
                        onClicked: ShellStore.checkForUpdates()
                    }
                    DesktopSettingsButton {
                        text: qsTr("Open releases")
                        enabled: Boolean(page.updater.releaseUrl)
                        onClicked: AppController.openExternalUrl(page.updater.releaseUrl || "")
                    }
                }
            }
        }
    }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        DesktopSettingsSection {
            text: ShellStore.releaseHighlights.title
                ? qsTr("RELEASE NOTES · %1").arg(String(ShellStore.releaseHighlights.title).toUpperCase())
                : qsTr("RELEASE NOTES")
        }
        ReleaseNotes {
            x: DesktopTokens.settingsInset
            width: parent.width - x * 2
            bottomPadding: DesktopTokens.settingsInset
            text: ShellStore.releaseHighlights.bodyMarkdown || qsTr("Check for updates to load verified release information from GitHub.")
            font.pixelSize: DesktopTokens.px(14)
        }
    }

    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        DesktopSettingsSection { text: qsTr("PREFERENCES") }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "arrows"; title: qsTr("Update channel")
            description: qsTr("Choose which releases OpenNOW checks")
            DesktopSettingsSegmented {
                options: [{label:qsTr("Stable"),value:"stable"},{label:qsTr("Nightly"),value:"nightly"}]
                objectName: "renewUpdateChannel"
                optionWidth: 96; selectedIndex: options.findIndex(item => item.value === page.settingsScreen.valueSetting("updateChannel","stable"))
                onSelected: (index,item) => page.settingsScreen.setChoice("updateChannel",item.value)
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "clock"; title: qsTr("Automatically check for updates")
            description: qsTr("Check every six hours while no streaming session is active.")
            DesktopSettingsToggle {
                objectName: "autoCheckUpdatesToggle"
                Accessible.name: qsTr("Automatically check for updates")
                checked: page.settingsScreen.boolSetting("autoCheckForUpdates", false)
                onValueChangedByUser: value => page.settingsScreen.setSetting("autoCheckForUpdates", value)
            }
        }
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "check"; title: qsTr("Automatically download updates")
            description: qsTr("Download verified updates while idle. Installation always requires your confirmation.")
            showDivider: false
            DesktopSettingsToggle {
                objectName: "autoDownloadUpdatesToggle"
                Accessible.name: qsTr("Automatically download updates")
                checked: page.settingsScreen.boolSetting("autoDownloadUpdates", false)
                onValueChangedByUser: value => page.settingsScreen.setSetting("autoDownloadUpdates", value)
            }
        }
    }
}
