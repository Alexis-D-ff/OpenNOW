import QtQuick
import QtQuick.Controls
import OpenNOW

AbstractButton {
    id: link
    property string glyph: ""
    property string trailing: ""
    property string chevron: ""
    property int pixelSize: DesktopTokens.px(12)
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Math.max(DesktopTokens.px(24), implicitContentHeight + topPadding + bottomPadding)
    leftPadding: DesktopTokens.px(4); rightPadding: DesktopTokens.px(4)
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.name: text
    Keys.onReturnPressed: event => { link.clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { link.clicked(); event.accepted = true }
    background: Rectangle {
        radius: DesktopTokens.px(6)
        color: link.hovered ? DesktopTokens.raised : "transparent"
        border.width: link.activeFocus ? 2 : 0
        border.color: DesktopTokens.focus
    }
    contentItem: Row {
        spacing: DesktopTokens.px(5)
        DesktopSettingsIcon {
            visible: link.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: DesktopTokens.px(13); height: width
            glyph: link.glyph; ink: Theme.focus
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: link.text; color: Theme.focus
            font.family: Theme.bodyFont; font.pixelSize: link.pixelSize; font.weight: Font.ExtraBold
        }
        Text {
            visible: link.trailing !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: link.trailing; color: Theme.focus
            font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.px(14); font.weight: Font.ExtraBold
        }
        DesktopSettingsIcon {
            visible: link.chevron !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: DesktopTokens.px(10); height: width
            rotation: link.chevron === "up" ? -90 : 90
            glyph: "chevron"; ink: Theme.focus
        }
    }
}
