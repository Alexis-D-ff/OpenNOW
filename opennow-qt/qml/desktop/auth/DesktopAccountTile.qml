import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import OpenNOW

// One "Who's playing?" tile. The picker owns focus and selection; a tile only
// renders what it is told and reports clicks, so focus never moves into it.
AbstractButton {
    id: root
    property var account: null
    property bool addTile: false
    property real unit: 1
    property real tileSize: 168
    property bool compact: false
    property bool avatarOnly: false
    property bool current: false
    property bool manageMode: false
    property bool lastUsed: false
    property bool switching: false
    property bool dimmed: false
    property string liveTier: ""
    property bool pointerHints: true
    signal removeRequested()

    readonly property real avatarSize: Math.round(tileSize * unit)
    property real cornerRadius: Math.round(avatarSize * 36 / 168)
    readonly property string displayName: addTile ? (compact ? qsTr("Add") : qsTr("Add account"))
        : String(account && account.displayName || qsTr("NVIDIA profile"))
    readonly property string tier: liveTier !== "" ? liveTier : String(account && account.membershipTier || "")
    readonly property string partnerName: account && account.alliance ? String(account.providerName || "") : ""
    readonly property bool locked: Boolean(account && account.hasPin)
    readonly property bool expired: Boolean(account && account.needsSignIn)
    readonly property var gradients: [
        ["#FFD166", "#FF8A80"], ["#FF6F9F", "#A78BFA"], ["#93B5FF", "#235BDB"], ["#6DE7B7", "#7FD4FF"],
        ["#6DE7B7", "#2F8F6E"], ["#FF8A9A", "#FFD166"], ["#9AA3B5", "#566075"], ["#A78BFA", "#7FD4FF"]
    ]
    readonly property var gradient: {
        const key = String(account && account.userId || displayName)
        let hash = 0
        for (let index = 0; index < key.length; ++index)
            hash = (hash * 31 + key.charCodeAt(index)) >>> 0
        return gradients[hash % gradients.length]
    }

    function u(value) { return Math.round(value * root.unit) }

    implicitWidth: avatarSize + u(compact ? 16 : 32)
    implicitHeight: avatarOnly ? avatarSize : column.implicitHeight
    focusPolicy: Qt.NoFocus
    hoverEnabled: pointerHints
    opacity: dimmed ? 0.42 : 1
    Behavior on opacity { NumberAnimation { duration: DesktopTokens.motionDuration } }
    Accessible.role: Accessible.Button
    Accessible.name: {
        if (addTile)
            return qsTr("Add account")
        const parts = [displayName]
        if (account && account.email)
            parts.push(String(account.email))
        if (tier !== "")
            parts.push(tier)
        if (partnerName !== "")
            parts.push(qsTr("Plays through %1, an alliance partner").arg(partnerName))
        if (lastUsed)
            parts.push(qsTr("Last used"))
        if (locked)
            parts.push(qsTr("PIN locked"))
        if (expired)
            parts.push(qsTr("Sign-in expired"))
        return parts.join(", ")
    }

    ToolTip.visible: pointerHints && hovered && !addTile && (nameLabel.truncated || Boolean(account && account.email))
    ToolTip.delay: 600
    ToolTip.text: account && account.email ? displayName + "\n" + String(account.email) : displayName

    background: Item {}
    contentItem: Column {
        id: column
        spacing: root.u(root.compact ? 8 : 14)

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.avatarSize
            height: root.avatarSize
            scale: root.switching ? pulse.value : (root.hovered && !root.current ? 1.025 : 1)
            Behavior on scale { NumberAnimation { duration: DesktopTokens.quickDuration } }

            QtObject {
                id: pulse
                property real value: 1
            }
            SequentialAnimation {
                running: root.switching && !AppController.reducedMotion
                loops: Animation.Infinite
                onRunningChanged: if (!running) pulse.value = 1
                NumberAnimation { target: pulse; property: "value"; to: 1.04; duration: 520; easing.type: Easing.InOutSine }
                NumberAnimation { target: pulse; property: "value"; to: 1; duration: 520; easing.type: Easing.InOutSine }
            }

            Rectangle {
                anchors.centerIn: parent
                visible: root.current
                width: parent.width + root.u(14)
                height: width
                radius: root.cornerRadius + root.u(7)
                color: root.expired ? DesktopTokens.amber : DesktopTokens.focus
            }
            Rectangle {
                anchors.centerIn: parent
                visible: root.current
                width: parent.width + root.u(8)
                height: width
                radius: root.cornerRadius + root.u(4)
                color: Theme.shell
            }

            Shape {
                anchors.fill: parent
                visible: !root.addTile
                opacity: root.manageMode ? 0.55 : 1
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0
                        x2: root.avatarSize; y2: root.avatarSize * 1.19
                        GradientStop { position: 0; color: root.gradient[0] }
                        GradientStop { position: 1; color: root.gradient[1] }
                    }
                    PathRectangle { width: root.avatarSize; height: root.avatarSize; radius: root.cornerRadius }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !root.addTile
                opacity: root.manageMode ? 0.55 : 1
                text: root.displayName.charAt(0).toUpperCase()
                color: "#0B0F1A"
                font.family: DesktopTokens.displayFont
                font.pixelSize: Math.round(root.avatarSize * 71 / 168)
                font.weight: Font.Black
            }

            Shape {
                anchors.fill: parent
                visible: root.addTile
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.current || root.hovered ? Qt.rgba(DesktopTokens.text.r, DesktopTokens.text.g, DesktopTokens.text.b, 0.55)
                        : Qt.rgba(DesktopTokens.text.r, DesktopTokens.text.g, DesktopTokens.text.b, 0.26)
                    strokeWidth: Math.max(1, root.u(2))
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 3]
                    fillColor: root.current || root.hovered ? DesktopTokens.raised : "transparent"
                    PathRectangle {
                        x: 1; y: 1
                        width: root.avatarSize - 2
                        height: root.avatarSize - 2
                        radius: root.cornerRadius
                    }
                }
            }
            DesktopGlyph {
                anchors.centerIn: parent
                visible: root.addTile
                width: Math.round(root.avatarSize * 40 / 168)
                height: width
                icon: "desktop-plus.svg"
            }

            Rectangle {
                visible: root.locked && !root.manageMode
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: root.u(root.compact ? 6 : 10)
                width: root.u(root.compact ? 22 : 30)
                height: width
                radius: root.u(root.compact ? 6 : 8)
                color: "#8C0B0F1A"
                DesktopGlyph {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.5)
                    height: width
                    icon: "desktop-lock-badge.svg"
                }
            }

            Rectangle {
                visible: root.compact && root.partnerName !== ""
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: -root.u(4)
                width: root.u(20)
                height: width
                radius: root.u(5)
                color: "#A78BFA"
                border.width: Math.max(1, root.u(2))
                border.color: Theme.shell
                Text {
                    anchors.centerIn: parent
                    text: root.partnerName.charAt(0).toUpperCase()
                    color: "#0B0F1A"
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: root.u(10)
                    font.weight: Font.Black
                }
            }

            Rectangle {
                visible: root.expired && !root.manageMode
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.round(root.avatarSize * (root.compact ? 0.26 : 0.2))
                bottomLeftRadius: root.cornerRadius
                bottomRightRadius: root.cornerRadius
                color: "#D90B0F1A"
                Text {
                    anchors.centerIn: parent
                    width: parent.width - root.u(8)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.compact ? qsTr("⚠ EXPIRED") : qsTr("⚠ SIGN IN AGAIN")
                    color: DesktopTokens.amber
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: root.u(root.compact ? 8 : 11)
                    font.weight: Font.Bold
                    font.letterSpacing: root.u(1)
                }
            }

            AbstractButton {
                objectName: "accountRemoveBadge"
                visible: root.manageMode && !root.addTile
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: -root.u(8)
                width: root.u(root.compact ? 22 : 28)
                height: width
                focusPolicy: Qt.NoFocus
                Accessible.name: qsTr("Remove %1 from this PC").arg(root.displayName)
                background: Rectangle {
                    radius: width / 2
                    color: parent.hovered ? "#3DFF8A80" : "#F20E1018"
                    border.width: 1
                    border.color: "#80FF8A80"
                }
                contentItem: DesktopGlyph {
                    width: parent.width * 0.45
                    height: width
                    icon: "desktop-close.svg"
                }
                onClicked: root.removeRequested()
            }
        }

        Column {
            visible: !root.avatarOnly
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width
            spacing: root.u(root.compact ? 4 : 8)

            Text {
                id: nameLabel
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: root.compact ? Text.NoWrap : Text.WordWrap
                maximumLineCount: root.compact ? 1 : 2
                elide: Text.ElideRight
                text: root.displayName
                color: root.current || root.addTile && root.hovered ? DesktopTokens.text
                    : Qt.rgba(DesktopTokens.text.r, DesktopTokens.text.g, DesktopTokens.text.b, root.addTile ? 0.74 : 0.84)
                font.family: DesktopTokens.bodyFont
                font.pixelSize: root.u(!root.compact ? 18 : root.tileSize >= 100 ? 15 : 13)
                font.weight: root.current ? Font.Black : Font.ExtraBold
            }

            Text {
                visible: root.compact && root.tier !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: compactChip.label
                color: compactChip.ink
                font.family: DesktopTokens.monoFont
                font.pixelSize: root.u(root.tileSize >= 100 ? 10 : 9)
                font.weight: Font.DemiBold
                font.letterSpacing: root.u(root.tileSize >= 100 ? 0.8 : 0.72)
                DesktopAccountChip { id: compactChip; visible: false; tier: root.tier; compactTier: true }
            }

            DesktopAccountChip {
                visible: !root.compact && root.tier !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                unit: root.unit
                tier: root.tier
            }
            DesktopAccountChip {
                visible: !root.compact && root.partnerName !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                unit: root.unit
                partnerName: root.partnerName
            }
            Row {
                visible: !root.compact && root.lastUsed && !root.addTile
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.u(6)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.u(6)
                    height: width
                    radius: width / 2
                    color: DesktopTokens.mint
                }
                Text {
                    text: qsTr("LAST USED")
                    color: Theme.lightMode ? "#127A50" : DesktopTokens.mint
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: root.u(10)
                    font.weight: Font.DemiBold
                    font.letterSpacing: root.u(10) * 0.1
                }
            }
        }
    }
}
