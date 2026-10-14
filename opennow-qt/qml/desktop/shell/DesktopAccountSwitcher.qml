import QtQuick
import QtQuick.Controls
import OpenNOW

// Sidebar account popover: who is signed in, one-step switching to any other
// saved account, and the account actions. Every switch goes through
// ShellStore.chooseAccount so PIN and running-session guards stay in one place.
FocusScope {
    id: root
    objectName: "desktopAccountSwitcher"
    property bool opened: false
    property int currentIndex: 0
    readonly property var activeUser: ShellStore.authSession && ShellStore.authSession.user ? ShellStore.authSession.user : null
    readonly property var activeAccount: {
        const accounts = ShellStore.savedAccounts || []
        for (let index = 0; index < accounts.length; ++index)
            if (ShellStore.isActiveAccount(accounts[index]))
                return accounts[index]
        return null
    }
    readonly property var others: (ShellStore.savedAccounts || []).filter(account => !ShellStore.isActiveAccount(account))
    readonly property int tileCount: others.length + 1
    readonly property var actions: [
        { key: "manage", icon: "desktop-pencil.svg", label: qsTr("Manage accounts") },
        { key: "settings", icon: "desktop-sliders.svg", label: qsTr("Account settings") },
        { key: "sign-out", icon: "desktop-logout.svg", label: qsTr("Sign out of %1").arg(activeName) }
    ]
    readonly property int itemCount: tileCount + actions.length
    readonly property var currentOther: currentIndex < others.length ? others[currentIndex] : null
    readonly property string activeName: String(activeUser && activeUser.displayName || qsTr("NVIDIA profile"))
    readonly property string activeTier: ShellStore.subscription && ShellStore.subscription.membershipTier
        ? String(ShellStore.subscription.membershipTier).toUpperCase()
        : String(activeUser && activeUser.membershipTier || "").toUpperCase()
    readonly property int columns: 5
    signal closeRequested()
    onCurrentIndexChanged: if (opened && currentIndex >= 0 && currentIndex < tileCount)
        switcherTiles.reveal(currentIndex)

    visible: reveal.present
    enabled: opened
    focus: opened
    MotionProgress { id: reveal; shown: root.opened }
    onOpenedChanged: {
        if (!opened)
            return
        currentIndex = 0
        ShellStore.accountMessage = ""
        ShellStore.refreshSavedAccounts()
        forceActiveFocus()
    }
    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Switch account")

    function u(value) { return DesktopTokens.px(value) }

    function activate(index) {
        if (index < others.length) {
            if (ShellStore.chooseAccount(others[index], false) !== "")
                closeRequested()
            return
        }
        closeRequested()
        if (index === others.length) {
            ShellStore.beginAddAccount()
            return
        }
        const action = actions[index - tileCount].key
        if (action === "manage")
            AppController.navigate("accounts")
        else if (action === "settings")
            AppController.navigate("settings-account")
        else
            ShellStore.logout()
    }

    Keys.onPressed: event => {
        const inTiles = currentIndex < tileCount
        switch (event.key) {
        case Qt.Key_Left:
            if (inTiles && currentIndex > 0) currentIndex--
            break
        case Qt.Key_Right:
            if (inTiles && currentIndex < tileCount - 1) currentIndex++
            break
        case Qt.Key_Up:
            if (!inTiles) currentIndex = currentIndex === tileCount ? Math.min(tileCount - 1, Math.floor((tileCount - 1) / columns) * columns) : currentIndex - 1
            else if (currentIndex >= columns) currentIndex -= columns
            break
        case Qt.Key_Down:
            if (inTiles) currentIndex = currentIndex + columns < tileCount ? currentIndex + columns : tileCount
            else if (currentIndex < itemCount - 1) currentIndex++
            break
        case Qt.Key_Tab:
            currentIndex = (currentIndex + 1) % itemCount
            break
        case Qt.Key_Backtab:
            currentIndex = (currentIndex + itemCount - 1) % itemCount
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            activate(currentIndex)
            break
        case Qt.Key_Escape:
        case Qt.Key_Back:
            closeRequested()
            break
        default:
            return
        }
        event.accepted = true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.closeRequested()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        id: card
        objectName: "accountSwitcherCard"
        x: DesktopTokens.railCollapsedWidth + root.u(12)
        y: Math.max(root.u(8), root.height - height - root.u(20))
        width: root.u(420)
        height: Math.min(content.implicitHeight, Math.max(root.u(160), root.height - root.u(16)))
        clip: true
        radius: root.u(16)
        color: Theme.lightMode ? "#FAFFFFFF" : "#F512161F"
        border.width: 1
        border.color: DesktopTokens.seam
        opacity: reveal.progress
        transform: Translate { y: (1 - reveal.progress) * root.u(10) }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: wheel => wheel.accepted = true }

        Column {
            id: content
            width: parent.width

            Row {
                x: root.u(16)
                width: parent.width - root.u(32)
                topPadding: root.u(16)
                bottomPadding: root.u(16)
                spacing: root.u(14)
                DesktopAccountTile {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.u(48)
                    account: root.activeAccount || (root.activeUser ? {userId: root.activeUser.userId, displayName: root.activeName} : null)
                    tileSize: 48
                    unit: DesktopTokens.uiScale
                    compact: true
                    avatarOnly: true
                    enabled: false
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - root.u(62)
                    spacing: root.u(4)
                    Row {
                        width: parent.width
                        spacing: root.u(8)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width - tierChip.width - activeLabel.width - root.u(16))
                            elide: Text.ElideRight
                            text: root.activeName
                            color: DesktopTokens.text
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: root.u(17)
                            font.weight: Font.Black
                        }
                        DesktopAccountChip {
                            id: tierChip
                            anchors.verticalCenter: parent.verticalCenter
                            unit: DesktopTokens.uiScale * 0.9
                            tier: root.activeTier
                        }
                        Row {
                            id: activeLabel
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.u(6)
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: root.u(6); height: width; radius: width / 2; color: DesktopTokens.mint }
                            Text {
                                text: qsTr("ACTIVE")
                                color: Theme.lightMode ? "#127A50" : DesktopTokens.mint
                                font.family: DesktopTokens.monoFont
                                font.pixelSize: root.u(10)
                                font.weight: Font.DemiBold
                                font.letterSpacing: root.u(1)
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: {
                            const email = String(root.activeAccount && root.activeAccount.email || root.activeUser && root.activeUser.email || "")
                            const provider = String(root.activeAccount && root.activeAccount.providerName
                                || ShellStore.authSession && ShellStore.authSession.provider && ShellStore.authSession.provider.displayName || "")
                            return [email, provider].filter(part => part !== "").join(" · ")
                        }
                        color: DesktopTokens.textMuted
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: root.u(13)
                        font.weight: Font.DemiBold
                    }
                }
            }

            Rectangle { x: root.u(16); width: parent.width - root.u(32); height: 1; color: DesktopTokens.seamSoft }

            Column {
                x: root.u(16)
                width: parent.width - root.u(32)
                topPadding: root.u(16)
                bottomPadding: root.u(14)
                spacing: root.u(14)
                Text {
                    text: qsTr("SWITCH TO")
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: root.u(10)
                    font.weight: Font.DemiBold
                    font.letterSpacing: root.u(1.4)
                }
                Flickable {
                    id: switcherTiles
                    objectName: "accountSwitcherTiles"
                    width: parent.width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: switcherTileFlow.implicitHeight
                    interactive: contentHeight > height + 1
                    height: Math.min(switcherTileFlow.implicitHeight,
                        Math.max(root.u(86), root.height - root.u(348)))
                    function reveal(index) {
                        const item = switcherTileRepeater.itemAt(index)
                        if (!item || contentHeight <= height)
                            return
                        const top = item.y
                        const bottom = item.y + item.height
                        if (top < contentY)
                            contentY = top
                        else if (bottom > contentY + height)
                            contentY = Math.max(0, bottom - height)
                    }
                    Flow {
                    id: switcherTileFlow
                    width: parent.width
                    spacing: root.u(2)
                    Repeater {
                        id: switcherTileRepeater
                        model: root.tileCount
                        DesktopAccountTile {
                            required property int index
                            objectName: index < root.others.length ? "accountSwitcherTile" + index : "accountSwitcherAddTile"
                            readonly property var tileAccount: index < root.others.length ? root.others[index] : null
                            width: root.u(76)
                            account: tileAccount
                            addTile: tileAccount === null
                            unit: DesktopTokens.uiScale
                            tileSize: 64
                            compact: true
                            current: index === root.currentIndex
                            switching: ShellStore.accountSwitchRequestId !== "" && tileAccount !== null
                                && String(tileAccount.userId) === ShellStore.accountSwitchTargetUserId
                            onClicked: {
                                root.currentIndex = index
                                root.activate(index)
                            }
                        }
                    }
                    }
                }
                Rectangle {
                    visible: root.currentOther !== null
                    width: parent.width
                    height: root.u(40)
                    radius: root.u(10)
                    color: DesktopTokens.seamSoft
                    Row {
                        x: root.u(12)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - root.u(24) - enterCap.width
                        spacing: root.u(8)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, root.u(150))
                            elide: Text.ElideRight
                            text: String(root.currentOther && root.currentOther.displayName || "")
                            color: DesktopTokens.text
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: root.u(13)
                            font.weight: Font.ExtraBold
                        }
                        DesktopAccountChip {
                            anchors.verticalCenter: parent.verticalCenter
                            unit: DesktopTokens.uiScale * 0.9
                            tier: String(root.currentOther && root.currentOther.membershipTier || "")
                        }
                        DesktopAccountChip {
                            anchors.verticalCenter: parent.verticalCenter
                            unit: DesktopTokens.uiScale * 0.9
                            partnerName: root.currentOther && root.currentOther.alliance ? String(root.currentOther.providerName || "") : ""
                        }
                    }
                    Rectangle {
                        id: enterCap
                        anchors.right: parent.right
                        anchors.rightMargin: root.u(10)
                        anchors.verticalCenter: parent.verticalCenter
                        width: enterText.implicitWidth + root.u(12)
                        height: root.u(22)
                        radius: root.u(5)
                        color: DesktopTokens.raisedStrong
                        Text {
                            id: enterText
                            anchors.centerIn: parent
                            text: root.currentOther && root.currentOther.needsSignIn ? qsTr("Sign in")
                                : root.currentOther && root.currentOther.hasPin ? qsTr("PIN") : qsTr("Enter")
                            color: DesktopTokens.text
                            font.family: DesktopTokens.monoFont
                            font.pixelSize: root.u(11)
                            font.weight: Font.DemiBold
                        }
                    }
                }
                Text {
                    objectName: "accountSwitcherError"
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: ShellStore.accountMessage
                    color: DesktopTokens.danger
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: root.u(13)
                    font.weight: Font.Bold
                }
            }

            Rectangle { x: root.u(16); width: parent.width - root.u(32); height: 1; color: DesktopTokens.seamSoft }

            Column {
                x: root.u(8)
                width: parent.width - root.u(16)
                topPadding: root.u(6)
                bottomPadding: root.u(6)
                Repeater {
                    model: root.actions
                    AbstractButton {
                        id: actionButton
                        required property int index
                        required property var modelData
                        readonly property bool current: root.currentIndex === root.tileCount + index
                        objectName: "accountSwitcherAction-" + modelData.key
                        width: parent.width
                        height: root.u(40)
                        focusPolicy: Qt.NoFocus
                        hoverEnabled: true
                        text: modelData.label
                        Accessible.name: text
                        onClicked: root.activate(root.tileCount + index)
                        background: Rectangle {
                            radius: root.u(9)
                            color: actionButton.current || actionButton.hovered ? DesktopTokens.raised : "transparent"
                            border.width: actionButton.current ? 2 : 0
                            border.color: DesktopTokens.focus
                        }
                        contentItem: Row {
                            leftPadding: root.u(12)
                            spacing: root.u(12)
                            DesktopGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.u(15)
                                height: width
                                icon: actionButton.modelData.icon
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: actionButton.text
                                color: actionButton.modelData.key === "sign-out" ? (Theme.lightMode ? "#B3261E" : "#FFB4AE") : DesktopTokens.text
                                font.family: DesktopTokens.bodyFont
                                font.pixelSize: root.u(14)
                                font.weight: Font.Bold
                            }
                        }
                    }
                }
            }

            Rectangle { x: root.u(16); width: parent.width - root.u(32); height: 1; color: DesktopTokens.seamSoft }

            Row {
                x: root.u(16)
                topPadding: root.u(12)
                bottomPadding: root.u(14)
                spacing: root.u(16)
                DesktopKeyHint { keyText: "← →"; shortcut: "Left"; label: qsTr("Pick"); compact: true }
                DesktopKeyHint { keyText: "Enter"; label: qsTr("Switch"); compact: true }
                DesktopKeyHint { keyText: "Ctrl+Shift+A"; label: qsTr("Open anywhere"); compact: true }
            }
        }
    }
}
