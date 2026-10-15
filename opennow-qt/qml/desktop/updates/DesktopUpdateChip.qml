import QtQuick
import QtQuick.Controls
import OpenNOW

// Status-bar chip. Hidden while there is nothing to act on.
AbstractButton {
    id: root
    objectName: "desktopUpdateChip"
    readonly property string attention: ShellStore.updaterAttention
    readonly property real fraction: ShellStore.updaterDownloadFraction
    property bool panelOpen: false
    readonly property color tone: attention === "ready" ? DesktopTokens.mint
        : attention === "error" ? DesktopTokens.danger : Theme.focus
    visible: attention !== ""
    focusPolicy: Qt.TabFocus
    hoverEnabled: true
    implicitHeight: DesktopTokens.px(24)
    implicitWidth: chipRow.implicitWidth + DesktopTokens.px(22)
    text: attention === "available" ? qsTr("UPDATE AVAILABLE")
        : attention === "downloading" ? (fraction < 0 ? qsTr("DOWNLOADING") : qsTr("DOWNLOADING · %1%").arg(Math.floor(fraction * 100)))
        : attention === "ready" ? qsTr("RESTART TO UPDATE")
        : attention === "installing" ? qsTr("INSTALLING UPDATE")
        : (ShellStore.updaterState || ({})).status === "error" ? qsTr("UPDATE CHECK FAILED") : qsTr("UPDATE FAILED")
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Updates: %1").arg(text)

    background: Rectangle {
        radius: height / 2
        color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, root.hovered || root.panelOpen ? 0.24 : 0.14)
        border.width: root.activeFocus || root.panelOpen ? 2 : 1
        border.color: root.activeFocus || root.panelOpen ? root.tone : Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.42)
    }
    contentItem: Item {
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: DesktopTokens.px(7)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(6); height: width; radius: width / 2
                color: root.tone
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: Theme.label
                font.family: DesktopTokens.monoFont
                font.pixelSize: DesktopTokens.px(11)
                font.weight: Font.Bold
                font.letterSpacing: 0.6
            }
        }
    }
}
