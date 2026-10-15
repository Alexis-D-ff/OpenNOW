import QtQuick
import OpenNOW

// Determinate when the core reports received bytes, indeterminate otherwise.
Item {
    id: root
    objectName: "updateDownloadProgress"
    readonly property real fraction: ShellStore.updaterDownloadFraction
    readonly property var progress: (ShellStore.updaterState || ({})).downloadProgress || ({})
    readonly property string amount: fraction < 0 ? ""
        : qsTr("%1 of %2 MB").arg((Number(progress.receivedBytes) / 1000000).toFixed(1))
            .arg((Number(progress.totalBytes) / 1000000).toFixed(1))
    visible: ShellStore.updaterBusy
    implicitHeight: DesktopTokens.px(18)
    Accessible.role: Accessible.ProgressBar
    Accessible.name: fraction < 0 ? qsTr("Update in progress") : qsTr("Downloading update, %1%").arg(Math.floor(fraction * 100))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (amountLabel.visible ? amountLabel.width + DesktopTokens.px(14) : 0)
        height: DesktopTokens.px(6)
        radius: height / 2
        color: DesktopTokens.raisedStrong
        clip: true
        Rectangle {
            objectName: "updateDownloadProgressFill"
            height: parent.height
            radius: height / 2
            color: Theme.focus
            width: root.fraction < 0 ? parent.width * 0.28 : parent.width * root.fraction
            x: root.fraction < 0 ? sweep.position * (parent.width + width) - width : 0
        }
        QtObject {
            id: sweep
            property real position: 0.5
        }
        NumberAnimation {
            target: sweep; property: "position"; from: 0; to: 1
            duration: 1400; loops: Animation.Infinite
            running: root.visible && root.fraction < 0 && !AppController.reducedMotion
        }
    }
    Text {
        id: amountLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.amount !== ""
        text: root.amount
        color: Theme.label
        font.family: DesktopTokens.monoFont
        font.pixelSize: DesktopTokens.px(12)
        font.weight: Font.DemiBold
    }
}
