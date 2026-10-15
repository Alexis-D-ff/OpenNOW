import QtQuick
import QtQuick.Controls
import OpenNOW

// Quick path from the status-bar chip: what changed and the one next action.
// Settings › Updates is the single home for channel, preferences and full notes.
Popup {
    id: root
    objectName: "desktopUpdatePanel"
    signal settingsRequested()
    readonly property var updater: ShellStore.updaterState || ({})
    readonly property string attention: ShellStore.updaterAttention
    readonly property var changes: String(ShellStore.releaseHighlights.bodyMarkdown || "").split("\n")
        .filter(line => /^\s*[-*+]\s+/.test(line))
        .map(line => line.replace(/^\s*[-*+]\s+/, "").replace(/\s+by @\S+ in \S+$/, "")
            .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/[*_`]/g, "").trim())
        .filter(line => line !== "")
    width: Math.min(DesktopTokens.px(400), Overlay.overlay ? Overlay.overlay.width - DesktopTokens.px(32) : DesktopTokens.px(400))
    padding: DesktopTokens.px(18)
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onOpened: ShellStore.acknowledgeUpdateHighlights()

    background: Rectangle {
        radius: DesktopTokens.px(14)
        color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.98)
        border.width: 1
        border.color: Theme.seam
    }

    contentItem: Column {
        spacing: DesktopTokens.px(16)
        Row {
            width: parent.width
            spacing: DesktopTokens.px(12)
            Rectangle {
                width: DesktopTokens.px(40); height: width; radius: DesktopTokens.px(12)
                color: DesktopTokens.raised
                Image {
                    anchors.centerIn: parent
                    width: DesktopTokens.px(24); height: DesktopTokens.px(14)
                    source: "qrc:/qt/qml/OpenNOW/res/brand/opennow-mark.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }
            Column {
                width: parent.width - DesktopTokens.px(52)
                anchors.verticalCenter: parent.verticalCenter
                spacing: DesktopTokens.px(3)
                DesktopUpdateHeadline {
                    width: parent.width
                    font.pixelSize: DesktopTokens.px(17)
                }
                Text {
                    width: parent.width
                    text: root.updater.availableVersion && root.attention !== "error"
                        ? qsTr("%1  →  %2").arg(root.updater.currentVersion || Qt.application.version).arg(root.updater.availableVersion)
                        : qsTr("INSTALLED %1").arg(root.updater.currentVersion || Qt.application.version)
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: DesktopTokens.px(10)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
        }
        Text {
            width: parent.width
            visible: root.attention === "error"
            text: ShellStore.updaterError || root.updater.message || ""
            textFormat: Text.PlainText
            color: Theme.label
            font.family: Theme.bodyFont
            font.pixelSize: DesktopTokens.px(13)
            wrapMode: Text.WordWrap
        }
        Column {
            objectName: "updatePanelChanges"
            width: parent.width
            visible: root.attention !== "error" && root.changes.length > 0
            spacing: DesktopTokens.px(4)
            Text {
                bottomPadding: DesktopTokens.px(4)
                text: qsTr("WHAT'S NEW")
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.px(10)
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
            Repeater {
                model: root.changes.slice(0, 3)
                delegate: Text {
                    required property string modelData
                    width: parent.width
                    text: "•  " + modelData
                    textFormat: Text.PlainText
                    color: Theme.label
                    font.family: Theme.bodyFont
                    font.pixelSize: DesktopTokens.px(13)
                    elide: Text.ElideRight
                }
            }
            Text {
                visible: root.changes.length > 3
                text: root.changes.length === 4 ? qsTr("+ 1 more change")
                    : qsTr("+ %1 more changes").arg(root.changes.length - 3)
                color: DesktopTokens.textMuted
                font.family: Theme.bodyFont
                font.pixelSize: DesktopTokens.px(13)
            }
        }
        Text {
            width: parent.width
            visible: !ShellStore.updaterSessionSafe && root.attention === "ready"
            text: qsTr("End your streaming session before installing an update. Background updates will wait.")
            color: Theme.textMuted
            font.family: Theme.bodyFont
            font.pixelSize: DesktopTokens.px(12)
            wrapMode: Text.WordWrap
        }
        DesktopUpdateProgress {
            width: parent.width
            visible: root.attention === "downloading"
        }
        Item {
            width: parent.width
            implicitHeight: Math.max(primaryAction.visible ? primaryAction.implicitHeight : 0, openSettings.implicitHeight)
            DesktopUpdatePrimaryAction {
                id: primaryAction
                visible: nextAction !== "downloading"
                panelLabels: true
                anchors.verticalCenter: parent.verticalCenter
            }
            AbstractButton {
                id: openSettings
                objectName: "updatePanelOpenSettings"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: openSettingsLabel.implicitWidth
                implicitHeight: DesktopTokens.px(28)
                text: qsTr("Open in Settings")
                Accessible.name: qsTr("Open Updates in Settings")
                contentItem: Text {
                    id: openSettingsLabel
                    text: openSettings.text
                    color: openSettings.hovered || openSettings.activeFocus ? Theme.label : Theme.textMuted
                    font.family: Theme.bodyFont
                    font.pixelSize: DesktopTokens.px(13)
                    font.weight: Font.Bold
                    font.underline: openSettings.activeFocus
                    verticalAlignment: Text.AlignVCenter
                }
                background: null
                onClicked: {
                    root.close()
                    root.settingsRequested()
                }
            }
        }
    }
}
