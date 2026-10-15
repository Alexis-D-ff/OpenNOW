import QtQuick
import OpenNOW

// The expanded body panel: one row per feature with its tier ladder.
Rectangle {
    id: panel
    required property DesktopGameDlss info
    readonly property string statsShortcut: String(ShellStore.settings.shortcutToggleStats ?? "Ctrl+N")
    objectName: "gameDlssPanel"
    radius: DesktopTokens.px(16)
    color: DesktopTokens.raised
    implicitHeight: panelContent.implicitHeight + (info.listed ? DesktopTokens.px(12) : DesktopTokens.px(28))
    Column {
        id: panelContent
        x: DesktopTokens.px(14); y: panel.info.listed ? DesktopTokens.px(4) : DesktopTokens.px(14)
        width: parent.width - DesktopTokens.px(28)
        spacing: panel.info.listed ? DesktopTokens.px(2) : DesktopTokens.px(10)
        Row {
            objectName: "gameDlssNotListedCard"
            visible: panel.info.notListed
            width: parent.width
            spacing: DesktopTokens.px(10)
            DesktopSettingsIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(16); height: width
                glyph: "info"; ink: Theme.textMuted
            }
            Column {
                width: parent.width - DesktopTokens.px(26)
                spacing: DesktopTokens.px(2)
                Text {
                    objectName: "gameDlssNotListedTitle"
                    width: parent.width; wrapMode: Text.WordWrap
                    text: qsTr("%1 isn't on NVIDIA's DLSS list").arg(String(panel.info.game && panel.info.game.title || qsTr("This game")))
                    color: Theme.label
                    font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.captionSize; font.weight: Font.ExtraBold
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: qsTr("Overrides only act on games that ship DLSS, so this game keeps its own graphics settings.")
                    color: Theme.textMuted
                    font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.px(12); font.weight: Font.Medium
                }
            }
        }
        Repeater {
            model: panel.info.rows
            delegate: Item {
                id: featureRow
                required property var modelData
                required property int index
                objectName: "gameDlssRow-" + modelData.key
                readonly property string answer: modelData.answer
                readonly property string source: modelData.source
                width: panelContent.width
                height: Math.max(DesktopTokens.px(26), answerText.implicitHeight + DesktopTokens.px(8))
                Rectangle { visible: featureRow.index > 0; width: parent.width; height: 1; color: DesktopTokens.seamSoft }
                Row {
                    id: nameCell
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(DesktopTokens.px(220), parent.width * 0.32)
                    spacing: DesktopTokens.px(6)
                    clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: featureRow.modelData.name; color: Theme.label
                        font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.captionSize; font.weight: Font.ExtraBold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: featureRow.source; color: DesktopTokens.textFaint
                        font.family: Theme.monoFont; font.pixelSize: DesktopTokens.tinySize; font.weight: Font.Bold
                        font.letterSpacing: DesktopTokens.tinySize * 0.06
                    }
                }
                Text {
                    id: answerText
                    anchors.verticalCenter: parent.verticalCenter
                    x: nameCell.width + DesktopTokens.px(12)
                    width: parent.width - x - ladderRow.width - DesktopTokens.px(12)
                    wrapMode: Text.WordWrap
                    text: featureRow.answer
                    color: Qt.rgba(Theme.label.r, Theme.label.g, Theme.label.b,
                        featureRow.modelData.status === "locked" ? 0.5 : featureRow.modelData.status === "neutral" ? 0.8 : 0.88)
                    font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.px(12); font.weight: Font.DemiBold
                }
                Row {
                    id: ladderRow
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: DesktopTokens.px(3)
                    Repeater {
                        model: featureRow.modelData.tiers
                        delegate: Item {
                            id: tierTag
                            required property string modelData
                            required property int index
                            readonly property string tierState: modelData
                            objectName: "gameDlssTier-" + featureRow.modelData.key + "-" + index
                            width: tierText.implicitWidth + DesktopTokens.px(12); height: DesktopTokens.px(18)
                            Rectangle {
                                anchors.fill: parent; radius: DesktopTokens.px(5)
                                visible: tierTag.tierState !== "unavailable"
                                color: tierTag.tierState === "included" ? Theme.focus
                                    : tierTag.tierState === "missing" ? DesktopTokens.amber : DesktopTokens.raisedStrong
                            }
                            DesktopDashedOutline {
                                anchors.fill: parent; radius: DesktopTokens.px(5)
                                visible: tierTag.tierState === "unavailable"
                                stroke: Qt.rgba(Theme.label.r, Theme.label.g, Theme.label.b, 0.15)
                            }
                            Text {
                                id: tierText
                                anchors.centerIn: parent
                                text: panel.info.tiers[tierTag.index].label
                                color: tierTag.tierState === "included" ? Theme.focusText
                                    : tierTag.tierState === "missing" ? "#2A2100"
                                    : tierTag.tierState === "unavailable" ? Qt.rgba(Theme.label.r, Theme.label.g, Theme.label.b, 0.25)
                                    : Qt.rgba(Theme.label.r, Theme.label.g, Theme.label.b, 0.8)
                                font.family: Theme.monoFont; font.pixelSize: DesktopTokens.tinySize; font.weight: Font.Bold
                                font.letterSpacing: DesktopTokens.tinySize * 0.08
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            id: strip
            objectName: "gameDlssStrip"
            readonly property var content: panel.info.strip
            readonly property color accent: content && content.kind === "signIn" ? Theme.focus : DesktopTokens.amber
            readonly property string text: content ? content.text : ""
            visible: content !== null
            width: parent.width
            height: Math.max(DesktopTokens.px(36), stripText.implicitHeight + DesktopTokens.px(10))
            radius: DesktopTokens.px(10)
            color: Qt.rgba(accent.r, accent.g, accent.b, 0.08)
            border.width: 1; border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.25)
            DesktopSettingsIcon {
                x: DesktopTokens.px(10); anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(15); height: width
                glyph: strip.content ? strip.content.glyph : "crown"; ink: strip.accent
            }
            Text {
                id: stripText
                x: DesktopTokens.px(35); anchors.verticalCenter: parent.verticalCenter
                width: stripAction.x - x - DesktopTokens.px(10)
                wrapMode: Text.WordWrap
                text: strip.text; color: Theme.label
                font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.px(12); font.weight: Font.Bold
            }
            DesktopButton {
                id: stripAction
                objectName: "gameDlssStripAction"
                anchors.right: parent.right; anchors.rightMargin: DesktopTokens.px(4)
                anchors.verticalCenter: parent.verticalCenter
                height: DesktopTokens.px(28); cornerRadius: DesktopTokens.px(10)
                leftPadding: DesktopTokens.px(10); rightPadding: DesktopTokens.px(10)
                font.pixelSize: DesktopTokens.px(11)
                text: strip.content ? strip.content.action : ""
                onClicked: panel.info.activateStrip()
                Keys.onReturnPressed: event => { stripAction.clicked(); event.accepted = true }
                Keys.onEnterPressed: event => { stripAction.clicked(); event.accepted = true }
            }
        }
        Item {
            objectName: "gameDlssFooter"
            width: parent.width
            height: footerLink.height + (panel.info.listed ? DesktopTokens.px(6) : DesktopTokens.px(10))
            Rectangle { width: parent.width; height: 1; color: DesktopTokens.seamSoft }
            Row {
                id: footerHints
                anchors.bottom: parent.bottom
                height: footerLink.height
                width: Math.min(implicitWidth, footerLink.x - DesktopTokens.px(8))
                clip: true
                spacing: DesktopTokens.px(8)
                Text {
                    visible: panel.info.listed
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Per NVIDIA's list. Developers can opt out.")
                    color: Theme.textMuted
                    font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.px(11); font.weight: Font.DemiBold
                }
                Row {
                    visible: panel.statsShortcut !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: DesktopTokens.px(4)
                    KeyboardGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        shortcut: panel.statsShortcut
                        keySize: DesktopTokens.px(18)
                        ink: Qt.rgba(Theme.label.r, Theme.label.g, Theme.label.b, 0.7)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.info.listed ? qsTr("shows the live status") : qsTr("in a session shows what really applies")
                        color: Theme.textMuted
                        font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.px(11); font.weight: Font.DemiBold
                    }
                }
            }
            DesktopTextLink {
                id: footerLink
                objectName: "gameDlssOverridesLink"
                anchors.right: parent.right; anchors.bottom: parent.bottom
                text: qsTr("DLSS overrides"); glyph: "sliders"; trailing: "›"
                onClicked: AppController.navigate("settings-streaming")
            }
        }
    }
}
