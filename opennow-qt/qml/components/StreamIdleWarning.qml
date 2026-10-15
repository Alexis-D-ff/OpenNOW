import QtQuick
import OpenNOW

Rectangle {
    id: root
    objectName: "streamIdleWarning"
    property double warningNowMs: Date.now()
    readonly property double secondsLeft: ShellStore.streamIdleWarning
        ? Math.max(0, Math.ceil(ShellStore.streamIdleWarning.secondsLeft
            - Math.max(0, warningNowMs - ShellStore.streamIdleWarning.receivedAtMs) / 1000)) : 0
    visible: ShellStore.streamIdleWarning !== null
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 32
    width: Math.min(560, parent.width - 48)
    height: copy.implicitHeight + 32
    radius: 12
    color: "#F0222936"
    border.color: "#BC9554"
    border.width: 1
    Accessible.role: Accessible.AlertMessage
    Accessible.name: heading.text + ". " + detail.text

    Connections {
        target: ShellStore
        function onStreamIdleWarningChanged() { root.warningNowMs = Date.now() }
    }

    Timer {
        interval: 250
        running: root.visible
        repeat: true
        onTriggered: root.warningNowMs = Date.now()
    }

    Column {
        id: copy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 6

        Text {
            id: heading
            width: parent.width
            text: qsTr("Are you still playing?")
            font.pixelSize: 17
            font.weight: Font.DemiBold
            color: "#FFE0A6"
            wrapMode: Text.Wrap
        }
        Text {
            id: detail
            width: parent.width
            text: qsTr("Your session will end in %1 seconds due to inactivity.")
                .arg(root.secondsLeft)
                + "\n" + qsTr("Use your keyboard, mouse, or controller to keep playing.")
            font.pixelSize: 14
            color: "#E3E7EF"
            wrapMode: Text.Wrap
        }
    }
}
