import QtQuick
import QtQuick.Controls
import OpenNOW

FocusScope {
    id: root
    objectName: "desktopIconGuide"
    property bool opened: false
    signal closeRequested()
    visible: reveal.present
    enabled: opened
    focus: opened
    onOpenedChanged: if (opened) Qt.callLater(root.restoreFocus)
    MotionProgress { id: reveal; shown: root.opened }
    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("What the icons mean")

    readonly property var storeKeys: ["steam", "epic", "gog", "xbox", "ubisoft", "ea", "battlenet", "gaijin", "nvidia"]

    function restoreFocus() {
        if (root.opened && !closeButton.activeFocus)
            closeButton.forceActiveFocus()
    }

    function handleKey(key) {
        if (key === Qt.Key_Escape || key === Qt.Key_Back) {
            root.closeRequested()
        } else if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
            closeButton.forceActiveFocus()
        } else if (key === Qt.Key_Up || key === Qt.Key_Down) {
            const step = key === Qt.Key_Up ? -DesktopTokens.px(40) : DesktopTokens.px(40)
            guideBody.contentY = Math.max(0, Math.min(guideBody.contentHeight - guideBody.height, guideBody.contentY + step))
        } else {
            return false
        }
        return true
    }

    Keys.onPressed: event => event.accepted = root.handleKey(event.key)

    component Mark: Rectangle {
        property alias content: markRow.data
        width: markRow.implicitWidth + 14
        height: 22
        radius: 7
        color: "#D90B0F1A"
        border.width: 1
        border.color: "#24FFFFFF"
        Row {
            id: markRow
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
        }
    }

    component Entry: Row {
        property alias mark: markHost.data
        property string label: ""
        property string detail: ""
        width: parent ? parent.width : 0
        spacing: DesktopTokens.px(14)
        Item {
            id: markHost
            width: DesktopTokens.px(64)
            height: 22
        }
        Column {
            width: parent.width - DesktopTokens.px(78)
            spacing: 2
            Text {
                width: parent.width
                text: parent.parent.label
                color: DesktopTokens.text
                wrapMode: Text.Wrap
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.captionSize
                font.weight: Font.Bold
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: parent.parent.detail
                color: DesktopTokens.textMuted
                wrapMode: Text.Wrap
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.smallSize
            }
        }
    }

    component SectionLabel: Text {
        color: DesktopTokens.textMuted
        font.family: DesktopTokens.monoFont
        font.pixelSize: DesktopTokens.tinySize
        font.weight: Font.Bold
        font.letterSpacing: 0.8
    }

    Rectangle {
        anchors.fill: parent
        color: "#A8000000"
        opacity: reveal.progress
        TapHandler { onTapped: root.closeRequested() }
    }

    Rectangle {
        id: panel
        objectName: "desktopIconGuidePanel"
        readonly property real chromeHeight: DesktopTokens.px(24) * 2 + header.height + footer.height + DesktopTokens.px(32)
        width: Math.min(DesktopTokens.px(560), root.width - DesktopTokens.px(48))
        height: Math.min(chromeHeight + guideColumn.implicitHeight, root.height - DesktopTokens.px(48))
        anchors.centerIn: parent
        radius: 18
        color: DesktopTokens.shell
        border.width: 1
        border.color: DesktopTokens.seam
        opacity: reveal.progress
        scale: reveal.zoom
        TapHandler { }

        Column {
            id: header
            x: DesktopTokens.px(24)
            y: DesktopTokens.px(24)
            width: parent.width - DesktopTokens.px(48)
            spacing: DesktopTokens.px(4)
            Text {
                width: parent.width
                text: qsTr("What the icons mean")
                color: DesktopTokens.textHigh
                wrapMode: Text.Wrap
                font.family: DesktopTokens.displayFont
                font.pixelSize: DesktopTokens.headingSize
                font.weight: Font.Black
            }
            Text {
                width: parent.width
                text: qsTr("Game tiles in Home, Library and Store use these marks. Hover or focus a game to see them spelled out.")
                color: DesktopTokens.textMuted
                wrapMode: Text.Wrap
                font.family: DesktopTokens.bodyFont
                font.pixelSize: DesktopTokens.smallSize
            }
        }

        Flickable {
            id: guideBody
            x: DesktopTokens.px(24)
            y: header.y + header.height + DesktopTokens.px(16)
            width: parent.width - DesktopTokens.px(48)
            height: footer.y - y - DesktopTokens.px(16)
            contentHeight: guideColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: guideColumn
                width: guideBody.width
                spacing: DesktopTokens.px(12)

                SectionLabel { text: qsTr("LAUNCHERS · BOTTOM LEFT") }
                Entry {
                    label: qsTr("A launcher you own")
                    detail: qsTr("Bright logo with a green dot. It comes first.")
                    mark: Mark {
                        content: Item {
                            width: 12
                            height: 12
                            Image { anchors.fill: parent; source: DesktopTokens.storeIconUrl("steam"); sourceSize: Qt.size(32, 32); fillMode: Image.PreserveAspectFit }
                            Rectangle { x: 9; y: 9; width: 6; height: 6; radius: 3; color: DesktopTokens.green; border.width: 1; border.color: "#0B0F1A" }
                        }
                    }
                }
                Entry {
                    label: qsTr("Another launcher you can play it from")
                    detail: qsTr("Dimmed logo. Pick it in the game's details.")
                    mark: Mark {
                        content: Image { width: 12; height: 12; opacity: 0.5; source: DesktopTokens.storeIconUrl("epic"); sourceSize: Qt.size(32, 32); fillMode: Image.PreserveAspectFit }
                    }
                }
                Entry {
                    label: qsTr("More launchers")
                    detail: qsTr("A tile shows up to three logos, then a count.")
                    mark: Mark {
                        content: Text { text: "+2"; color: "#CCFFFFFF"; font.family: DesktopTokens.monoFont; font.pixelSize: 10; font.weight: Font.Bold }
                    }
                }
                Flow {
                    objectName: "desktopIconGuideStores"
                    width: parent.width
                    spacing: DesktopTokens.px(12)
                    Repeater {
                        model: root.storeKeys
                        Row {
                            id: storeEntry
                            required property string modelData
                            spacing: 6
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 7
                                color: "#D90B0F1A"
                                Image { anchors.centerIn: parent; width: 12; height: 12; source: DesktopTokens.storeIconUrl(storeEntry.modelData); sourceSize: Qt.size(32, 32); fillMode: Image.PreserveAspectFit }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: DesktopTokens.storeLabel(storeEntry.modelData)
                                color: DesktopTokens.textMuted
                                font.family: DesktopTokens.bodyFont
                                font.pixelSize: DesktopTokens.smallSize
                            }
                        }
                    }
                }

                SectionLabel { text: qsTr("FEATURES · BOTTOM RIGHT") }
                Text {
                    width: parent.width
                    text: qsTr("Shown only when GeForce NOW's catalog lists the feature for that game.")
                    color: DesktopTokens.textMuted
                    wrapMode: Text.Wrap
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: DesktopTokens.smallSize
                }
                Repeater {
                    model: DesktopTokens.gameFeatureKeys
                    Entry {
                        id: featureEntry
                        required property string modelData
                        objectName: "desktopIconGuideFeature-" + modelData
                        label: DesktopTokens.featureLabel(modelData)
                        detail: modelData === "dlss" ? qsTr("From NVIDIA's DLSS games list, not the GeForce NOW catalog.") : ""
                        mark: Mark {
                            content: Image { width: 12; height: 12; source: DesktopTokens.featureIconUrl(featureEntry.modelData); sourceSize: Qt.size(32, 32) }
                        }
                    }
                }

                SectionLabel { text: qsTr("MEMBERSHIP · TOP RIGHT") }
                Entry {
                    label: qsTr("Needs a paid membership")
                    detail: qsTr("Your current plan can't start this game.")
                    mark: Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: "#D90B0F1A"
                        border.width: 1
                        border.color: "#24FFFFFF"
                        Image { anchors.centerIn: parent; width: 12; height: 12; source: "qrc:/qt/qml/OpenNOW/res/icons/desktop-lock.svg"; sourceSize: Qt.size(32, 32) }
                    }
                }
            }
        }

        Item {
            id: footer
            x: DesktopTokens.px(24)
            y: parent.height - height - DesktopTokens.px(24)
            width: parent.width - DesktopTokens.px(48)
            height: closeButton.height
            DesktopButton {
                id: closeButton
                objectName: "desktopIconGuideClose"
                anchors.right: parent.right
                primary: true
                text: qsTr("Close")
                onClicked: root.closeRequested()
            }
        }
    }
}
