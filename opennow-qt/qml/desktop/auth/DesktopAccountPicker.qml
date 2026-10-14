import QtQuick
import QtQuick.Controls
import OpenNOW

// "Who's playing?" — the one saved-account picker for launch, the sidebar's
// "Manage accounts", settings and console mode. Keyboard focus stays on this
// scope; the highlighted tile is `currentIndex`, so focus can never be lost
// to a tile that disappears after a switch or removal.
FocusScope {
    id: root
    objectName: "desktopAccountPicker"
    property bool consoleMode: false
    readonly property real unit: consoleMode ? 1.2 : DesktopTokens.uiScale
    readonly property var accounts: ShellStore.savedAccounts || []
    readonly property int itemCount: accounts.length + 1
    readonly property bool compact: accounts.length >= 6
    readonly property bool tightPicker: !consoleMode && stage.height > 0 && stage.height < u(560)
    readonly property real tileSize: consoleMode ? (compact ? 150 : 196) : (compact ? 132 : 168)
    readonly property real cellWidth: u(tileSize + (compact ? 16 : 32))
    readonly property real cellGap: u(compact ? 20 : consoleMode ? 36 : 28)
    readonly property int columns: Math.max(1, Math.min(itemCount, compact ? 5 : 6,
        Math.floor((width - u(96) + cellGap) / (cellWidth + cellGap))))
    readonly property var currentAccount: currentIndex >= 0 && currentIndex < accounts.length ? accounts[currentIndex] : null
    readonly property bool switching: ShellStore.accountSwitchRequestId !== ""
    readonly property string switchingUserId: ShellStore.accountSwitchTargetUserId
    readonly property var switchingAccount: accountById(switchingUserId)
    readonly property string activeTier: ShellStore.subscription && ShellStore.subscription.membershipTier
        ? String(ShellStore.subscription.membershipTier).toUpperCase() : ""
    readonly property bool canLeave: ShellStore.signedIn
    property int currentIndex: 0
    property bool manageMode: false
    property var pinAccount: null
    property string pinEntry: ""
    property var confirmTarget: null
    property string confirmKind: ""

    function u(value) { return Math.round(value * root.unit) }

    function accountById(userId) {
        for (let index = 0; index < accounts.length; ++index)
            if (String(accounts[index].userId) === String(userId))
                return accounts[index]
        return null
    }

    function initialIndex() {
        for (let index = 0; index < accounts.length; ++index)
            if (ShellStore.isActiveAccount(accounts[index]))
                return index
        return 0
    }

    function nameOf(account) {
        return String(account && account.displayName || qsTr("NVIDIA profile"))
    }

    function move(delta) {
        currentIndex = Math.max(0, Math.min(itemCount - 1, currentIndex + delta))
        grid.reveal(currentIndex)
    }

    function activate(index) {
        if (switching || index < 0 || index >= itemCount)
            return
        currentIndex = index
        if (index === accounts.length) {
            if (!manageMode)
                ShellStore.beginAddAccount()
            return
        }
        const account = accounts[index]
        if (manageMode) {
            askToRemove(account)
            return
        }
        const outcome = ShellStore.chooseAccount(account, !consoleMode)
        if (outcome === "pin") {
            pinAccount = account
            pinEntry = ""
            ShellStore.pinMessage = ""
        } else if (outcome === "active") {
            ShellStore.leaveAccountPicker()
        }
    }

    function askToRemove(account) {
        confirmKind = "remove"
        confirmTarget = account
    }

    function closeConfirm() {
        confirmKind = ""
        confirmTarget = null
    }

    function acceptConfirm() {
        if (confirmKind === "remove" && confirmTarget)
            ShellStore.removeAccount(confirmTarget.userId)
        else if (confirmKind === "sign-out-all")
            ShellStore.logoutAll()
        closeConfirm()
    }

    function typePin(digit) {
        if (switching || pinEntry.length >= 4)
            return
        pinEntry += digit
        ShellStore.pinMessage = ""
        if (pinEntry.length === 4)
            ShellStore.switchAccount(pinAccount.userId, pinEntry)
    }

    function goBack() {
        if (pinAccount) {
            pinAccount = null
            pinEntry = ""
            ShellStore.pinMessage = ""
        } else if (confirmKind !== "") {
            closeConfirm()
        } else if (manageMode) {
            manageMode = false
        } else if (canLeave) {
            ShellStore.leaveAccountPicker()
        } else if (consoleMode) {
            AppController.showOverlay("application-quit-confirm")
        }
    }

    function digitOf(event) {
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            return event.key - Qt.Key_0
        return -1
    }

    focus: true
    Component.onCompleted: currentIndex = initialIndex()
    onItemCountChanged: currentIndex = Math.max(0, Math.min(currentIndex, itemCount - 1))
    Connections {
        target: ShellStore
        function onAccountSwitchRequestIdChanged() {
            if (ShellStore.accountSwitchRequestId === "" && root.pinAccount && ShellStore.pinMessage !== "")
                root.pinEntry = ""
        }
    }

    Keys.onPressed: event => {
        const digit = digitOf(event)
        if (confirmKind !== "") {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) acceptConfirm()
            else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) closeConfirm()
            event.accepted = true
            return
        }
        if (pinAccount) {
            if (digit >= 0) typePin(String(digit))
            else if (event.key === Qt.Key_Backspace) pinEntry = pinEntry.slice(0, -1)
            else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) goBack()
            event.accepted = true
            return
        }
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        switch (event.key) {
        case Qt.Key_Left: move(-1); break
        case Qt.Key_Right: move(1); break
        case Qt.Key_Up: if (currentIndex >= columns) move(-columns); break
        case Qt.Key_Down: if (currentIndex + columns < itemCount) move(columns); else if (Math.floor(currentIndex / columns) < Math.floor((itemCount - 1) / columns)) move(itemCount - 1 - currentIndex); break
        case Qt.Key_PageUp: move(-Math.max(columns, 1)); break
        case Qt.Key_PageDown: move(Math.max(columns, 1)); break
        case Qt.Key_Home: move(-currentIndex); break
        case Qt.Key_End: move(itemCount - 1 - currentIndex); break
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space: activate(currentIndex); break
        case Qt.Key_N:
        case Qt.Key_X: if (!switching) ShellStore.beginAddAccount(); break
        case Qt.Key_E:
        case Qt.Key_Y: if (!switching) manageMode = !manageMode; break
        case Qt.Key_Delete: if (manageMode && currentAccount) askToRemove(currentAccount); break
        case Qt.Key_Escape:
        case Qt.Key_Back: goBack(); break
        default:
            if (digit < 1 || digit > Math.min(9, accounts.length))
                return
            activate(digit - 1)
        }
        event.accepted = true
    }

    component KeyCap: Rectangle {
        property alias text: capLabel.text
        implicitWidth: Math.max(root.u(22), capLabel.implicitWidth + root.u(12))
        implicitHeight: root.u(22)
        radius: root.u(5)
        color: Theme.lightMode ? Qt.rgba(0.04, 0.06, 0.1, 0.1) : "#24FFFFFF"
        Text {
            id: capLabel
            anchors.centerIn: parent
            color: DesktopTokens.text
            font.family: DesktopTokens.monoFont
            font.pixelSize: root.u(11)
            font.weight: Font.DemiBold
        }
    }

    component KeyHint: Row {
        id: hint
        property var keys: []
        property string label: ""
        spacing: root.u(6)
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(3)
            Repeater {
                model: hint.keys
                KeyCap { required property string modelData; text: modelData }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: hint.label
            color: Qt.rgba(DesktopTokens.text.r, DesktopTokens.text.g, DesktopTokens.text.b, 0.72)
            font.family: DesktopTokens.bodyFont
            font.pixelSize: root.u(13)
            font.weight: Font.DemiBold
        }
    }

    component PickerButton: AbstractButton {
        id: pickerButton
        property string glyph: ""
        property string keyText: ""
        property bool danger: false
        implicitHeight: root.u(38)
        implicitWidth: buttonRow.implicitWidth + root.u(32)
        focusPolicy: Qt.NoFocus
        hoverEnabled: true
        Accessible.name: text
        background: Rectangle {
            radius: root.u(10)
            color: pickerButton.danger ? (pickerButton.hovered ? "#33FF8A80" : "#1AFF8A80")
                : pickerButton.hovered ? DesktopTokens.raisedStrong : DesktopTokens.raised
            border.width: 1
            border.color: pickerButton.danger ? "#66FF8A80" : DesktopTokens.seam
        }
        contentItem: Item {
            Row {
                id: buttonRow
                anchors.centerIn: parent
                spacing: root.u(10)
                DesktopGlyph {
                    visible: pickerButton.glyph !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.u(15)
                    height: width
                    icon: pickerButton.glyph
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pickerButton.text
                    color: pickerButton.danger ? DesktopTokens.danger : DesktopTokens.text
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: root.u(14)
                    font.weight: Font.ExtraBold
                }
                Text {
                    visible: pickerButton.keyText !== "" && !root.consoleMode
                    anchors.verticalCenter: parent.verticalCenter
                    text: pickerButton.keyText
                    color: Qt.rgba(DesktopTokens.text.r, DesktopTokens.text.g, DesktopTokens.text.b, 0.45)
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: root.u(10)
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    DesktopOnboardingBackdrop { anchors.fill: parent }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => { root.forceActiveFocus(); mouse.accepted = false }
    }

    Item {
        id: topStrip
        width: parent.width
        height: root.u(root.consoleMode ? 110 : 80)

        Rectangle {
            visible: root.consoleMode
            x: root.u(52)
            anchors.verticalCenter: parent.verticalCenter
            width: consoleBrand.width + root.u(44)
            height: root.u(50)
            radius: height / 2
            color: DesktopTokens.raised
            border.width: 1
            border.color: DesktopTokens.seam
            DesktopBrandLockup {
                id: consoleBrand
                anchors.centerIn: parent
                markHeight: root.u(18)
                fontPixelSize: root.u(18)
            }
        }
        Row {
            visible: !root.consoleMode
            x: root.u(40)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(12)
            DesktopBrandLockup {
                anchors.verticalCenter: parent.verticalCenter
                markHeight: root.u(18)
                fontPixelSize: root.u(20)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: versionLabel.implicitWidth + root.u(16)
                height: root.u(20)
                radius: root.u(6)
                color: DesktopTokens.raised
                Text {
                    id: versionLabel
                    anchors.centerIn: parent
                    text: Qt.application.version || qsTr("unknown")
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: root.u(11)
                }
            }
        }
        Row {
            visible: !root.consoleMode && ShellStore.sessionPersistence === "os-credential-store"
                && root.width >= root.u(900)
            anchors.right: parent.right
            anchors.rightMargin: root.u(40)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(8)
            DesktopGlyph {
                anchors.verticalCenter: parent.verticalCenter
                width: root.u(13)
                height: width
                opacity: 0.6
                icon: "desktop-lock-badge.svg"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Sign-ins are kept in your system keychain")
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: root.u(13)
                font.weight: Font.DemiBold
            }
        }
    }

    Item {
        id: stage
        objectName: "accountPickerStage"
        clip: true
        anchors.top: topStrip.bottom
        anchors.bottom: footer.top
        anchors.bottomMargin: root.consoleMode ? root.u(92) : 0
        width: parent.width

        Column {
            id: body
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            y: Math.max(0, (stage.height - height) / 2 - root.u(root.consoleMode ? 10 : 24))
            spacing: 0
            opacity: root.pinAccount ? 0 : root.confirmKind !== "" ? 0.16 : 1
            visible: opacity > 0
            enabled: root.confirmKind === "" && !root.pinAccount
            Behavior on opacity { NumberAnimation { duration: DesktopTokens.quickDuration } }

            Column {
                id: headingBlock
                objectName: "accountPickerHeading"
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.u(10)
                bottomPadding: stage.height < root.u(560) ? root.u(8) : root.u(root.compact ? 36 : 56)
                Text {
                    visible: !root.consoleMode
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.manageMode ? qsTr("MANAGE ACCOUNTS")
                        : root.accounts.length === 1 ? qsTr("1 ACCOUNT ON THIS PC")
                        : qsTr("%1 ACCOUNTS ON THIS PC").arg(root.accounts.length)
                    color: root.manageMode ? DesktopTokens.danger : Qt.rgba(DesktopTokens.text.r, DesktopTokens.text.g, DesktopTokens.text.b, 0.56)
                    font.family: DesktopTokens.monoFont
                    font.pixelSize: root.u(11)
                    font.weight: Font.DemiBold
                    font.letterSpacing: root.u(11) * 0.12
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Who’s playing?")
                    color: DesktopTokens.text
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: root.u(root.consoleMode ? 64 : root.tightPicker ? 32 : root.compact ? 44 : 56)
                    font.weight: Font.Black
                    font.letterSpacing: -root.u(root.consoleMode ? 1.28 : root.compact ? 0.88 : 1.12)
                    Accessible.role: Accessible.Heading
                }
                Text {
                    visible: !root.tightPicker
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, root.width - root.u(64))
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.manageMode ? qsTr("Remove a saved sign-in. Captures and settings stay on this PC.")
                        : root.consoleMode ? qsTr("Pick with the D-pad or left stick.")
                        : qsTr("Each account keeps its own library, membership and sign-in.")
                    color: Qt.rgba(DesktopTokens.text.r, DesktopTokens.text.g, DesktopTokens.text.b, 0.68)
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: root.u(root.consoleMode ? 19 : 17)
                    font.weight: root.consoleMode ? Font.DemiBold : Font.Medium
                }
            }

            Flickable {
                id: grid
                objectName: "accountPickerGrid"
                readonly property int rows: Math.ceil(root.itemCount / root.columns)
                readonly property real rowHeight: tileRepeater.count > 0 && tileRepeater.itemAt(0)
                    ? tileRepeater.itemAt(0).height : root.u(root.tileSize + 80)
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(root.width, tiles.width + root.u(32))
                height: {
                    const capped = Math.min(tiles.height, rowHeight * Math.min(rows, 2) + root.u(28))
                    const reserved = headingBlock.height + noticeBlock.height + actionBlock.height + root.u(12)
                    const room = Math.max(0, stage.height - reserved)
                    return Math.min(capped + root.u(16), room)
                }
                contentWidth: width
                contentHeight: tiles.height + root.u(16)
                interactive: contentHeight > height
                clip: interactive
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: grid.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

                function reveal(index) {
                    const item = tileRepeater.itemAt(index)
                    if (!item || !interactive)
                        return
                    const top = item.y
                    const bottom = item.y + item.height + root.u(16)
                    if (top < contentY)
                        contentY = top
                    else if (bottom > contentY + height)
                        contentY = bottom - height
                }

                Flow {
                    id: tiles
                    x: (grid.width - width) / 2
                    y: root.u(8)
                    width: root.columns * root.cellWidth + (root.columns - 1) * root.cellGap
                    spacing: root.cellGap

                    Repeater {
                        id: tileRepeater
                        model: root.itemCount
                        DesktopAccountTile {
                            required property int index
                            objectName: index < root.accounts.length ? "accountTile" + index : "accountAddTile"
                            readonly property var tileAccount: index < root.accounts.length ? root.accounts[index] : null
                            width: root.cellWidth
                            account: tileAccount
                            addTile: tileAccount === null
                            unit: root.unit
                            tileSize: root.tileSize
                            compact: root.compact
                            current: index === root.currentIndex
                            manageMode: root.manageMode
                            lastUsed: ShellStore.isActiveAccount(tileAccount)
                            liveTier: ShellStore.isActiveAccount(tileAccount) ? root.activeTier : ""
                            pointerHints: !root.consoleMode
                            switching: root.switching && tileAccount !== null
                                && String(tileAccount.userId) === root.switchingUserId
                            dimmed: root.switching && !switching || root.manageMode && addTile
                            enabled: !(root.manageMode && addTile)
                            onClicked: {
                                root.forceActiveFocus()
                                root.activate(index)
                            }
                            onRemoveRequested: {
                                root.forceActiveFocus()
                                root.currentIndex = index
                                root.askToRemove(tileAccount)
                            }
                        }
                    }
                }
            }

            Item {
                id: noticeBlock
                readonly property bool noticeShown: focusStrip.visible || root.switching || ShellStore.accountMessage !== ""
                    || root.currentAccount !== null && root.currentAccount.needsSignIn === true && !root.manageMode
                width: parent.width
                height: noticeShown ? root.u(root.tightPicker ? 40 : 92) : root.tightPicker ? 0 : root.u(44)
                visible: height > 0

                Row {
                    id: focusStrip
                    visible: !root.tightPicker && root.compact && root.currentAccount !== null && !root.switching
                        && !root.currentAccount.needsSignIn
                    anchors.centerIn: parent
                    spacing: root.u(10)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, root.u(360))
                        elide: Text.ElideRight
                        text: root.nameOf(root.currentAccount)
                        color: DesktopTokens.text
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: root.u(15)
                        font.weight: Font.Black
                    }
                    DesktopAccountChip {
                        anchors.verticalCenter: parent.verticalCenter
                        unit: root.unit
                        tier: root.currentAccount && ShellStore.isActiveAccount(root.currentAccount) && root.activeTier !== ""
                            ? root.activeTier : String(root.currentAccount && root.currentAccount.membershipTier || "")
                    }
                    DesktopAccountChip {
                        anchors.verticalCenter: parent.verticalCenter
                        unit: root.unit
                        partnerName: root.currentAccount && root.currentAccount.alliance ? String(root.currentAccount.providerName || "") : ""
                    }
                }

                Rectangle {
                    objectName: "accountExpiredNotice"
                    visible: root.currentAccount !== null && root.currentAccount.needsSignIn === true
                        && !root.manageMode && !root.switching
                    anchors.centerIn: parent
                    width: expiredRow.implicitWidth + root.u(32)
                    height: root.u(38)
                    radius: root.u(10)
                    color: "#1FFFD166"
                    border.width: 1
                    border.color: "#66FFD166"
                    Row {
                        id: expiredRow
                        anchors.centerIn: parent
                        spacing: root.u(8)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⚠"
                            color: DesktopTokens.amber
                            font.pixelSize: root.u(14)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.consoleMode
                                ? qsTr("%1’s sign-in expired · Press A to sign in again").arg(root.nameOf(root.currentAccount))
                                : qsTr("%1’s sign-in expired · Enter to sign in again").arg(root.nameOf(root.currentAccount))
                            color: Theme.lightMode ? "#7A5600" : DesktopTokens.amber
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: root.u(14)
                            font.weight: Font.Bold
                        }
                    }
                }

                Column {
                    objectName: "accountSwitchingStatus"
                    visible: root.switching
                    anchors.centerIn: parent
                    spacing: root.u(6)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Loading %1’s library…").arg(root.nameOf(root.switchingAccount))
                        color: DesktopTokens.text
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: root.u(18)
                        font.weight: Font.Black
                    }
                }

                Text {
                    objectName: "accountActionError"
                    visible: !root.switching && ShellStore.accountMessage !== ""
                        && !(root.currentAccount && root.currentAccount.needsSignIn)
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, root.width - root.u(64))
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.tightPicker ? 1 : 3
                    elide: root.tightPicker ? Text.ElideRight : Text.ElideNone
                    text: ShellStore.accountMessage
                    color: DesktopTokens.danger
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: root.u(14)
                    font.weight: Font.Bold
                }
            }

            Column {
                id: actionBlock
                visible: !root.consoleMode
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.u(18)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.u(10)
                    PickerButton {
                        objectName: "accountManageButton"
                        text: root.manageMode ? qsTr("Done") : qsTr("Manage accounts")
                        glyph: root.manageMode ? "" : "desktop-pencil.svg"
                        keyText: "E"
                        enabled: !root.switching
                        onClicked: root.manageMode = !root.manageMode
                    }
                    PickerButton {
                        objectName: "accountPinButton"
                        visible: root.manageMode && root.currentAccount !== null
                        text: root.currentAccount && root.currentAccount.hasPin
                            ? qsTr("Remove %1’s PIN").arg(root.nameOf(root.currentAccount))
                            : qsTr("Set a PIN for %1").arg(root.nameOf(root.currentAccount))
                        onClicked: ShellStore.openPin(root.currentAccount.hasPin ? "clear" : "set", root.currentAccount)
                    }
                    PickerButton {
                        objectName: "accountSignOutAllButton"
                        visible: root.manageMode
                        danger: true
                        text: qsTr("Sign out everyone")
                        onClicked: root.confirmKind = "sign-out-all"
                    }
                }
                AbstractButton {
                    id: skipToggle
                    objectName: "accountPickerSkipToggle"
                    visible: !root.manageMode && root.accounts.length >= 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    checkable: true
                    checked: ShellStore.settings.startAsLastUsedAccount === true
                    focusPolicy: Qt.NoFocus
                    hoverEnabled: true
                    implicitWidth: skipRow.implicitWidth
                    implicitHeight: root.u(24)
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: skipLabel.text
                    Accessible.checked: checked
                    onToggled: ShellStore.setSetting("startAsLastUsedAccount", checked)
                    contentItem: Row {
                        id: skipRow
                        spacing: root.u(10)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.u(18)
                            height: width
                            radius: root.u(5)
                            color: skipToggle.checked ? DesktopTokens.focus : "transparent"
                            border.width: Math.max(1, root.u(1.5))
                            border.color: skipToggle.checked ? DesktopTokens.focus
                                : Qt.rgba(DesktopTokens.text.r, DesktopTokens.text.g, DesktopTokens.text.b, skipToggle.hovered ? 0.6 : 0.4)
                            Text {
                                anchors.centerIn: parent
                                visible: skipToggle.checked
                                text: "✓"
                                color: "#0B0F1A"
                                font.pixelSize: root.u(12)
                                font.weight: Font.Black
                            }
                        }
                        Text {
                            id: skipLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Skip this screen and start as the last-used account")
                            color: DesktopTokens.textMuted
                            font.family: DesktopTokens.bodyFont
                            font.pixelSize: root.u(13)
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        Column {
            objectName: "accountPinPad"
            visible: root.pinAccount !== null
            anchors.centerIn: parent
            spacing: root.u(22)

            DesktopAccountTile {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.cellWidth
                account: root.pinAccount
                unit: root.unit
                tileSize: root.consoleMode ? 196 : 168
                current: true
                switching: root.switching
                focusPolicy: Qt.NoFocus
                enabled: false
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Enter %1’s PIN").arg(root.nameOf(root.pinAccount))
                color: DesktopTokens.textMuted
                font.family: DesktopTokens.bodyFont
                font.pixelSize: root.u(15)
                font.weight: Font.Bold
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.u(14)
                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("%1 of 4 digits entered").arg(root.pinEntry.length)
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: root.u(18)
                        height: width
                        radius: width / 2
                        color: index < root.pinEntry.length ? DesktopTokens.text : "transparent"
                        border.width: Math.max(1, root.u(2))
                        border.color: index < root.pinEntry.length ? DesktopTokens.text
                            : Qt.rgba(DesktopTokens.text.r, DesktopTokens.text.g, DesktopTokens.text.b, 0.5)
                    }
                }
            }
            Text {
                objectName: "accountPinError"
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: ShellStore.pinMessage
                color: DesktopTokens.danger
                font.family: DesktopTokens.bodyFont
                font.pixelSize: root.u(14)
                font.weight: Font.Bold
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.u(18)
                KeyHint { keys: ["0–9"]; label: qsTr("Type PIN") }
                KeyHint { keys: ["Esc"]; label: qsTr("Back") }
            }
        }

        Rectangle {
            objectName: "accountRemoveConfirmation"
            visible: root.confirmKind !== ""
            anchors.centerIn: parent
            width: Math.min(root.u(460), parent.width - root.u(48))
            height: confirmColumn.implicitHeight + root.u(48)
            radius: root.u(16)
            color: Theme.lightMode ? "#F7FFFFFF" : "#F50E1018"
            border.width: 1
            border.color: DesktopTokens.seam
            Accessible.role: Accessible.Dialog
            Accessible.name: confirmTitle.text

            Column {
                id: confirmColumn
                x: root.u(24)
                y: root.u(24)
                width: parent.width - root.u(48)
                spacing: root.u(10)
                Text {
                    id: confirmTitle
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: root.confirmKind === "sign-out-all" ? qsTr("Sign out everyone on this PC?")
                        : qsTr("Remove %1 from this PC?").arg(root.nameOf(root.confirmTarget))
                    color: DesktopTokens.text
                    font.family: DesktopTokens.displayFont
                    font.pixelSize: root.u(20)
                    font.weight: Font.Black
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: root.confirmKind === "sign-out-all"
                        ? qsTr("Deletes every saved sign-in and PIN. Captures and settings stay on this PC.")
                        : qsTr("Deletes the saved sign-in and PIN. %1 can sign in again any time.").arg(root.nameOf(root.confirmTarget))
                    color: DesktopTokens.textMuted
                    font.family: DesktopTokens.bodyFont
                    font.pixelSize: root.u(14)
                    font.weight: Font.Medium
                    lineHeight: 1.2
                }
                Row {
                    topPadding: root.u(8)
                    spacing: root.u(10)
                    PickerButton {
                        objectName: "accountRemoveKeep"
                        text: qsTr("Keep")
                        keyText: qsTr("Esc")
                        onClicked: root.closeConfirm()
                    }
                    PickerButton {
                        objectName: "accountRemoveConfirm"
                        danger: true
                        text: root.confirmKind === "sign-out-all" ? qsTr("Sign out everyone") : qsTr("Remove")
                        keyText: qsTr("Enter")
                        onClicked: root.acceptConfirm()
                    }
                }
            }
        }
    }

    Rectangle {
        id: footer
        objectName: "accountPickerFooter"
        visible: !root.consoleMode
        anchors.bottom: parent.bottom
        width: parent.width
        height: root.consoleMode ? 0 : root.u(52)
        color: Qt.rgba(Theme.shell.r, Theme.shell.g, Theme.shell.b, 0.78)
        Rectangle { width: parent.width; height: 1; color: DesktopTokens.seamSoft }

        Row {
            x: root.u(24)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(22)
            visible: !root.pinAccount && root.confirmKind === ""
            KeyHint { keys: ["←", "→"]; label: qsTr("Choose") }
            KeyHint {
                keys: ["Enter"]
                label: root.manageMode ? qsTr("Remove")
                    : root.currentAccount ? qsTr("Play as %1").arg(root.nameOf(root.currentAccount)) : qsTr("Add account")
            }
            KeyHint { keys: ["E"]; label: root.manageMode ? qsTr("Done") : qsTr("Manage") }
            KeyHint { visible: !root.manageMode; keys: ["N"]; label: qsTr("Add account") }
            KeyHint {
                visible: !root.manageMode && root.accounts.length > 1 && root.width >= root.u(1100)
                keys: [root.accounts.length > 9 ? "1–9" : "1–" + root.accounts.length]
                label: qsTr("Jump to account")
            }
        }
        KeyHint {
            visible: root.canLeave && !root.pinAccount && root.confirmKind === ""
            anchors.right: parent.right
            anchors.rightMargin: root.u(24)
            anchors.verticalCenter: parent.verticalCenter
            keys: ["Esc"]
            label: root.manageMode ? qsTr("Done") : qsTr("Back")
        }
    }

    Item {
        visible: root.consoleMode
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.u(40)
        x: root.u(52)
        width: parent.width - root.u(104)
        height: root.u(52)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(28)
            visible: !root.pinAccount && root.confirmKind === ""
            ControllerGlyph { glyph: "Y"; label: root.manageMode ? qsTr("Done") : qsTr("Manage"); glyphSize: root.u(24); labelPixelSize: root.u(13); labelWeight: Font.DemiBold }
            ControllerGlyph { visible: !root.manageMode; glyph: "X"; label: qsTr("Add account"); glyphSize: root.u(24); labelPixelSize: root.u(13); labelWeight: Font.DemiBold }
            Row {
                visible: grid.rows > 1
                spacing: root.u(3)
                ControllerGlyph { glyph: "LB"; label: ""; glyphSize: root.u(24) }
                ControllerGlyph { glyph: "RB"; label: qsTr("Page"); glyphSize: root.u(24); labelPixelSize: root.u(13); labelWeight: Font.DemiBold }
            }
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(28)
            ControllerGlyph {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "B"
                label: root.pinAccount || root.confirmKind !== "" || root.canLeave || root.manageMode ? qsTr("Back") : qsTr("Quit")
                glyphSize: root.u(24)
                labelPixelSize: root.u(13)
                labelWeight: Font.DemiBold
            }
            Rectangle {
                visible: !root.pinAccount && !root.switching
                anchors.verticalCenter: parent.verticalCenter
                width: playRow.implicitWidth + root.u(36)
                height: root.u(52)
                radius: height / 2
                color: Theme.lightMode ? "#0B0F1A" : "#FFFFFF"
                Row {
                    id: playRow
                    anchors.centerIn: parent
                    spacing: root.u(10)
                    ControllerGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "A"
                        label: ""
                        glyphColor: Theme.lightMode ? "#FFFFFF" : "#0A0D14"
                        glyphSize: root.u(24)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.confirmKind !== "" ? (root.confirmKind === "sign-out-all" ? qsTr("Sign out everyone") : qsTr("Remove"))
                            : root.manageMode ? qsTr("Remove")
                            : root.currentAccount ? qsTr("Play as %1").arg(root.nameOf(root.currentAccount)) : qsTr("Add account")
                        color: Theme.lightMode ? "#FFFFFF" : "#0A0D14"
                        font.family: DesktopTokens.bodyFont
                        font.pixelSize: root.u(17)
                        font.weight: Font.Black
                    }
                }
            }
        }
    }
}
