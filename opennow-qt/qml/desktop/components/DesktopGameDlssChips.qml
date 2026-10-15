import QtQuick
import OpenNOW

// The hero row: one chip per supported feature and the details toggle.
Flow {
    id: chips
    required property DesktopGameDlss info
    property bool expanded: false
    signal toggleRequested()
    objectName: "gameDlssChips"
    visible: info.listed || info.notListed
    spacing: DesktopTokens.px(6)
    Text {
        height: DesktopTokens.px(24); verticalAlignment: Text.AlignVCenter
        text: qsTr("DLSS"); color: Qt.rgba(Theme.label.r, Theme.label.g, Theme.label.b, 0.8)
        font.family: Theme.monoFont; font.pixelSize: DesktopTokens.px(10); font.weight: Font.Bold
        font.letterSpacing: DesktopTokens.px(10) * 0.14
    }
    Repeater {
        model: chips.info.rows
        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property bool included: modelData.status === "included"
            readonly property bool locked: modelData.status === "locked"
            readonly property string label: modelData.chip
            objectName: "gameDlssChip-" + modelData.key
            width: chipContent.implicitWidth + DesktopTokens.px(18); height: DesktopTokens.px(24); radius: height / 2
            color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, locked ? 0.5 : 0.7)
            border.width: locked ? 0 : 1
            border.color: included ? Qt.rgba(Theme.focus.r, Theme.focus.g, Theme.focus.b, 0.4) : DesktopTokens.raisedStrong
            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.name + ", " + modelData.answer
            DesktopDashedOutline { anchors.fill: parent; visible: chip.locked; radius: chip.radius }
            Row {
                id: chipContent
                anchors.centerIn: parent
                spacing: DesktopTokens.px(4)
                DesktopSettingsIcon {
                    objectName: "gameDlssChipIcon"
                    visible: chip.modelData.status !== "neutral"
                    anchors.verticalCenter: parent.verticalCenter
                    width: DesktopTokens.px(11); height: width
                    glyph: chip.included ? "check" : "lock"
                    ink: chip.included ? Theme.focus : DesktopTokens.amber
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.label
                    color: chip.included ? Theme.focus : chip.locked ? Qt.rgba(Theme.label.r, Theme.label.g, Theme.label.b, 0.5)
                        : Qt.rgba(Theme.label.r, Theme.label.g, Theme.label.b, 0.8)
                    font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.px(11)
                    font.weight: chip.locked ? Font.Bold : Font.ExtraBold
                }
            }
        }
    }
    Rectangle {
        objectName: "gameDlssNotListedChip"
        visible: chips.info.notListed
        width: notListedText.implicitWidth + DesktopTokens.px(18); height: DesktopTokens.px(24); radius: height / 2
        color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.7)
        border.width: 1; border.color: DesktopTokens.raisedStrong
        Text {
            id: notListedText
            anchors.centerIn: parent
            text: qsTr("Not on NVIDIA's list"); color: Qt.rgba(Theme.label.r, Theme.label.g, Theme.label.b, 0.8)
            font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.px(11); font.weight: Font.ExtraBold
        }
    }
    Text {
        objectName: "gameDlssPlanCaption"
        visible: chips.info.listed
        height: DesktopTokens.px(24); verticalAlignment: Text.AlignVCenter
        text: chips.info.planKnown ? qsTr("on your plan") : qsTr("per NVIDIA's list")
        color: Qt.rgba(Theme.label.r, Theme.label.g, Theme.label.b, 0.6)
        font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.px(11); font.weight: Font.DemiBold
    }
    DesktopTextLink {
        objectName: "gameDlssToggle"
        text: chips.expanded ? qsTr("Hide") : qsTr("What you get")
        pixelSize: DesktopTokens.px(11)
        chevron: chips.expanded ? "up" : "down"
        Accessible.description: qsTr("DLSS")
        onClicked: chips.toggleRequested()
    }
}
