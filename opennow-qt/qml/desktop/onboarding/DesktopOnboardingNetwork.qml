pragma ComponentBehavior: Bound
import QtQuick
import OpenNOW

Rectangle {
    id: root
    objectName: "onboardingMacNetwork"
    property var controller: MacAwdl
    visible: controller.state !== MacAwdlController.Unsupported
    implicitHeight: content.implicitHeight + DesktopTokens.px(40)
    radius: DesktopTokens.px(16)
    color: Theme.lightMode ? Theme.glass : "#C70B0F1A"
    border.color: Theme.seam

    Column {
        id: content
        x: DesktopTokens.px(22)
        y: DesktopTokens.px(20)
        width: parent.width - DesktopTokens.px(44)
        spacing: DesktopTokens.px(14)

        Text {
            width: parent.width
            text: qsTr("Optional macOS network helper")
            color: Theme.label
            font.family: Theme.bodyFont
            font.pixelSize: DesktopTokens.px(20)
            font.weight: Font.Black
            wrapMode: Text.Wrap
            Accessible.role: Accessible.Heading
        }

        Text {
            objectName: "onboardingAwdlStatus"
            width: parent.width
            text: qsTr("AWDL suppression is optional and off by default. You can install its helper and enable it in desktop Settings > Network. It runs only while streaming, can affect AirDrop and related features, and is not a guaranteed fix for stutter. You can finish setup without it.")
            color: Theme.textMuted
            font.family: Theme.bodyFont
            font.pixelSize: DesktopTokens.px(13)
            wrapMode: Text.Wrap
            lineHeightMode: Text.FixedHeight
            lineHeight: DesktopTokens.px(18)
        }
    }
}
