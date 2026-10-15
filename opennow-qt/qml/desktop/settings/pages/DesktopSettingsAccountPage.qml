import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import OpenNOW

Column {
    id: page
    objectName: "desktopAccountSettings"
    required property real availableWidth
    required property var settingsScreen
    required property Component profilePageComponent
    required property Component subscriptionPageComponent
    required property Component storesPageComponent

    width: page.availableWidth; spacing: DesktopTokens.px(12)
    Loader { width: parent.width; sourceComponent: page.profilePageComponent }
    Loader { width: parent.width; sourceComponent: page.subscriptionPageComponent }
    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "person"; title: qsTr("Profiles")
            description: ShellStore.savedAccounts.length === 1 ? qsTr("1 account on this PC")
                : qsTr("%1 accounts on this PC").arg(ShellStore.savedAccounts.length)
            DesktopSettingsButton { objectName: "accountSettingsManage"; text: qsTr("Manage"); onClicked: AppController.navigate("accounts") }
        }
        DesktopSettingsRow {
            objectName: "accountStartAsLastUsed"
            width: parent.width; paperStyle: true; glyph: "person"; title: qsTr("Skip “Who’s playing?”")
            description: qsTr("Skip this screen and start as the last-used account"); showDivider: false
            DesktopSettingsToggle { checked: page.settingsScreen.boolSetting("startAsLastUsedAccount",false); onValueChangedByUser: value => page.settingsScreen.setSetting("startAsLastUsedAccount",value) }
        }
    }
    Loader { width: parent.width; sourceComponent: page.storesPageComponent }
    DesktopSettingsPanel {
        width: parent.width; paperStyle: true
        DesktopSettingsSection { text: qsTr("PRIVACY") }
        DesktopSettingsRow { objectName: "accountActivitySharing"; width: parent.width; paperStyle: true; glyph: "person"; title: qsTr("Show what I am playing"); description: qsTr("Discord activity sharing")
            DesktopSettingsToggle { checked: page.settingsScreen.boolSetting("discordRichPresence",false); onValueChangedByUser: value => page.settingsScreen.setSetting("discordRichPresence",value) }
        }
        DesktopSettingsRow { objectName: "accountAutomaticBugReports"; width: parent.width; paperStyle: true; glyph: "info"; title: qsTr("Usage & bug reports · Experimental"); description: qsTr("Send usage statistics and error reports with logs to the developer, identified by your GeForce NOW username or e-mail"); showDivider: false
            DesktopSettingsToggle { checked: ShellStore.bugReports.enabled; onValueChangedByUser: value => ShellStore.bugReports.setEnabled(value, "settings") }
        }
    }
    DesktopSettingsPanel {
        visible: ShellStore.signedIn
        width: parent.width; paperStyle: true
        DesktopSettingsRow {
            width: parent.width; paperStyle: true; glyph: "person"; title: qsTr("Sign out"); showDivider: false
            DesktopSettingsButton { text: qsTr("Sign out"); danger: true; onClicked: ShellStore.logout() }
        }
    }
}
