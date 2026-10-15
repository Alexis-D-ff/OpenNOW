pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import OpenNOW

FocusScope {
    id: root
    objectName: "desktopOnboardingScreen"
    property var store: ShellStore
    property int stepIndex: 0
    readonly property bool networkAvailable: store.onboardingAwdlController.state !== MacAwdlController.Unsupported
    readonly property var steps: networkAvailable ? ["mode", "picture", "network", "boost", "ready"]
        : ["mode", "picture", "boost", "ready"]
    readonly property int stepCount: steps.length
    readonly property string step: steps[Math.min(stepIndex, stepCount - 1)]
    readonly property bool saving: store.onboardingSaving
    readonly property string error: store.onboardingError
    readonly property var settings: store.onboardingSettings
    readonly property bool compact: width < DesktopTokens.px(960)
    readonly property color mint: Theme.accentColor("green")
    readonly property color amber: Theme.accentColor("amber")
    readonly property color coral: Theme.accentColor("coral")
    readonly property string displayName: store.authSession && store.authSession.user
        ? String(store.authSession.user.displayName || "") : ""
    readonly property string membership: store.subscription && store.subscription.membershipTier
        ? String(store.subscription.membershipTier).toUpperCase() : ""
    readonly property var stepNames: ({mode: qsTr("Mode"), picture: qsTr("Picture"), network: qsTr("Network"),
        boost: qsTr("Boost"), ready: qsTr("Ready")})
    readonly property var titles: ({mode: qsTr("Desk or couch?"), picture: qsTr("How should it look?"),
        network: qsTr("An optional network helper."), boost: qsTr("Try an experimental boost?"),
        ready: displayName !== "" ? qsTr("You're set, %1.").arg(displayName) : qsTr("You're set.")})
    readonly property var introductions: ({
        mode: qsTr("Pick the shell you'll open most. Both share one library and one set of settings."),
        picture: qsTr("Start with what your display and membership allow. You can fine-tune any time."),
        network: qsTr("Optional AWDL suppression is available in desktop Settings > Network. It stays off by default."),
        boost: qsTr("Both run on your GPU after the stream is decoded. They start off, so skipping is safe."),
        ready: qsTr("Here's what you picked. Finish to save it and open your library.")})
    readonly property var boostKeys: ["frameGeneration", "upscaling", "upscalingSharpness", "upscalingDenoise"]

    focus: true

    function updateUiScale() {
        if (width <= 0 || height <= 0)
            return
        const fitted = DesktopTokens.scaleForWindow(width, height)
        const preference = Number(store.settings.desktopUiScale || 1)
        DesktopTokens.uiScale = Math.min(1.4, Math.max(0.9, fitted * preference))
    }

    onWidthChanged: updateUiScale()
    onHeightChanged: updateUiScale()
    Component.onCompleted: updateUiScale()
    Connections {
        target: root.store
        function onSettingsChanged() { root.updateUiScale() }
    }

    function goToStep(index) {
        if (saving)
            return
        stepIndex = Math.max(0, Math.min(stepCount - 1, index))
    }

    function next() {
        if (saving)
            return
        if (stepIndex < stepCount - 1) {
            goToStep(stepIndex + 1)
            return
        }
        store.finishOnboarding()
    }

    function skipBoost() {
        if (saving)
            return
        store.resetOnboardingSettings(boostKeys)
        next()
    }

    function skip() {
        if (saving)
            return
        store.finishOnboarding()
    }

    function revealFocusedControl() {
        const win = root.Window.window
        const focused = win ? win.activeFocusItem : null
        if (!focused || (focused === nextButton && focused.focusReason === Qt.OtherFocusReason))
            return
        let ancestor = focused
        while (ancestor && ancestor !== pageBody)
            ancestor = ancestor.parent
        if (!ancestor)
            return
        ancestor = focused.parent
        while (ancestor) {
            if (ancestor instanceof Flickable) {
                const margin = Math.min(DesktopTokens.px(16), Math.max(0, (ancestor.height - focused.height) / 2))
                const point = focused.mapToItem(ancestor.contentItem, 0, 0)
                if (point.y < ancestor.contentY + margin)
                    ancestor.contentY = Math.max(0, point.y - margin)
                else if (point.y + focused.height > ancestor.contentY + ancestor.height - margin)
                    ancestor.contentY = Math.min(Math.max(0, ancestor.contentHeight - ancestor.height),
                        point.y + focused.height - ancestor.height + margin)
            }
            if (ancestor === pageScroll)
                break
            ancestor = ancestor.parent
        }
    }

    onStepCountChanged: goToStep(stepIndex)
    onStepIndexChanged: {
        nextButton.forceActiveFocus(Qt.OtherFocusReason)
        pageScroll.contentY = 0
    }
    Keys.onReturnPressed: event => { root.next(); event.accepted = true }
    Keys.onEnterPressed: event => { root.next(); event.accepted = true }
    Keys.onEscapePressed: event => { root.skip(); event.accepted = true }
    Shortcut {
        sequence: "Alt+Left"
        enabled: root.visible && root.enabled && !root.saving && root.stepIndex > 0
        onActivated: root.goToStep(root.stepIndex - 1)
    }
    Shortcut {
        sequence: "Alt+Right"
        enabled: root.visible && root.enabled && !root.saving
        onActivated: root.next()
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { Qt.callLater(root.revealFocusedControl) }
    }

    DesktopOnboardingBackdrop { anchors.fill: parent }

    component Copy: Text {
        width: parent.width
        color: Theme.textMuted
        font.family: Theme.bodyFont
        font.pixelSize: DesktopTokens.bodySize
        wrapMode: Text.Wrap
        font.weight: Font.Medium
        lineHeightMode: Text.FixedHeight
        lineHeight: DesktopTokens.px(23)
        height: lineCount * lineHeight
    }
    component Eyebrow: Text {
        color: root.mint
        font.family: Theme.monoFont
        font.pixelSize: DesktopTokens.px(10)
        font.weight: Font.Bold
        font.letterSpacing: DesktopTokens.px(1)
        lineHeightMode: Text.FixedHeight
        lineHeight: DesktopTokens.px(12)
        height: lineCount * lineHeight
        wrapMode: Text.Wrap
    }
    component Action: Button {
        id: action
        property bool primary: false
        property color accent: root.mint
        property string keyHint: ""
        property real cornerRadius: DesktopTokens.px(10)
        hoverEnabled: true
        padding: 0
        leftPadding: DesktopTokens.px(20)
        rightPadding: DesktopTokens.px(20)
        implicitHeight: DesktopTokens.px(48)
        background: Rectangle {
            radius: action.cornerRadius
            color: action.primary ? action.accent : action.hovered || action.down ? DesktopTokens.raisedStrong : DesktopTokens.seamSoft
            border.width: action.activeFocus ? 2 : 1
            border.color: action.activeFocus ? Theme.focus : action.primary ? action.accent : Theme.seam
            Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
        }
        contentItem: Text {
            id: actionLabel
            rightPadding: action.keyHint !== "" ? keyBadge.width + DesktopTokens.px(12) : 0
            text: action.text
            color: action.primary ? Theme.contrastText(action.accent) : Theme.label
            font.family: Theme.bodyFont
            font.pixelSize: DesktopTokens.px(14)
            font.weight: Font.ExtraBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        Rectangle {
            id: keyBadge
            visible: action.keyHint !== ""
            anchors.right: parent.right; anchors.rightMargin: action.rightPadding
            anchors.verticalCenter: parent.verticalCenter
            width: keyText.implicitWidth + DesktopTokens.px(16)
            height: DesktopTokens.px(action.primary ? 32 : 22)
            radius: DesktopTokens.px(6)
            color: action.primary ? "#0B0F1A" : DesktopTokens.raised
            Text {
                id: keyText
                anchors.centerIn: parent
                text: action.keyHint
                color: action.primary ? action.accent : Theme.textMuted
                font.family: Theme.monoFont; font.pixelSize: DesktopTokens.px(10)
                font.weight: Font.Bold
            }
        }
        implicitWidth: actionLabel.implicitWidth + leftPadding + rightPadding
        opacity: enabled ? 1 : 0.55
    }

    component Card: Rectangle {
        default property alias content: contents.data
        implicitHeight: contents.implicitHeight + 2
        color: Theme.lightMode ? Theme.glass : "#C70B0F1A"
        radius: DesktopTokens.px(16)
        border.color: Theme.seam
        Column {
            id: contents
            x: 1; y: 1; width: parent.width - 2
        }
    }

    component CardHeading: Rectangle {
        property string text: ""
        property string note: ""
        property color ink: Theme.textMuted
        width: parent.width
        height: DesktopTokens.px(41)
        color: DesktopTokens.seamSoft
        Eyebrow {
            x: DesktopTokens.px(18); anchors.verticalCenter: parent.verticalCenter
            text: parent.text; color: parent.ink
        }
        Eyebrow {
            anchors.right: parent.right; anchors.rightMargin: DesktopTokens.px(18)
            anchors.verticalCenter: parent.verticalCenter
            text: parent.note; color: Theme.textMuted; font.weight: Font.Medium
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.seam }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: DesktopTokens.px(72)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: DesktopTokens.px(root.compact ? 20 : 40)
                anchors.rightMargin: DesktopTokens.px(root.compact ? 20 : 40)
                spacing: DesktopTokens.px(10)
                DesktopBrandLockup {
                }
                Rectangle {
                    visible: !root.compact
                    implicitWidth: versionLabel.implicitWidth + DesktopTokens.px(14)
                    implicitHeight: DesktopTokens.px(24)
                    radius: DesktopTokens.px(6); color: DesktopTokens.raised
                    Text {
                        id: versionLabel
                        anchors.centerIn: parent; text: Qt.application.version
                        color: Theme.textMuted; font.family: Theme.monoFont
                        font.pixelSize: DesktopTokens.px(11); font.weight: Font.Bold
                    }
                }
                Rectangle {
                    implicitWidth: betaLabel.implicitWidth + DesktopTokens.px(16)
                    implicitHeight: DesktopTokens.px(24)
                    radius: DesktopTokens.px(6)
                    color: Qt.rgba(root.amber.r,root.amber.g,root.amber.b,0.12)
                    Text {
                        id: betaLabel
                        anchors.centerIn: parent
                        text: qsTr("BETA")
                        color: root.amber; font.family: Theme.monoFont
                        font.pixelSize: DesktopTokens.smallSize; font.weight: Font.Bold
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    visible: !root.compact && root.displayName !== ""
                    implicitWidth: DesktopTokens.px(28); implicitHeight: implicitWidth
                    radius: width / 2; color: DesktopTokens.raised
                    Text {
                        anchors.centerIn: parent; text: root.displayName.charAt(0).toUpperCase()
                        color: Theme.label; font.family: Theme.bodyFont
                        font.pixelSize: DesktopTokens.px(12); font.weight: Font.Black
                    }
                }
                Text {
                    visible: !root.compact
                    text: root.displayName !== "" ? qsTr("Signed in as %1").arg(root.displayName)
                        : root.store.signedIn ? qsTr("Signed in") : qsTr("Offline setup")
                    color: Theme.textMuted; font.family: Theme.bodyFont
                    font.pixelSize: DesktopTokens.px(12)
                }
                Eyebrow {
                    visible: !root.compact && root.membership !== ""
                    text: root.membership
                }
                Rectangle {
                    visible: !root.compact
                    Layout.leftMargin: DesktopTokens.px(6); Layout.rightMargin: DesktopTokens.px(6)
                    implicitWidth: 1; implicitHeight: DesktopTokens.px(16); color: Theme.seam
                }
                Action {
                    objectName: "onboardingSkip"
                    text: root.width < DesktopTokens.px(500) ? qsTr("Skip") : qsTr("Skip setup")
                    keyHint: root.compact ? "" : "Esc"
                    cornerRadius: height / 2
                    leftPadding: DesktopTokens.px(14); rightPadding: DesktopTokens.px(6)
                    implicitHeight: DesktopTokens.px(32)
                    enabled: !root.saving
                    onClicked: root.skip()
                }
            }
            Row {
                id: progress
                objectName: "onboardingProgress"
                anchors.horizontalCenter: parent.horizontalCenter
                y: DesktopTokens.px(22)
                spacing: DesktopTokens.px(8)
                Repeater {
                    model: root.steps
                    delegate: AbstractButton {
                        id: segment
                        required property int index
                        required property string modelData
                        width: DesktopTokens.px(root.compact ? 64 : 96)
                        height: DesktopTokens.px(root.compact ? 28 : 32)
                        enabled: !root.saving
                        hoverEnabled: true
                        Accessible.name: qsTr("Step %1: %2").arg(index + 1).arg(root.stepNames[modelData])
                        Accessible.role: Accessible.PageTab
                        Accessible.selected: root.stepIndex === index
                        onClicked: root.goToStep(index)
                        background: Rectangle {
                            x: -DesktopTokens.px(4); y: -DesktopTokens.px(4)
                            width: parent.width + DesktopTokens.px(8); height: parent.height + DesktopTokens.px(4)
                            radius: DesktopTokens.px(6)
                            color: segment.hovered ? DesktopTokens.seamSoft : "transparent"
                            border.width: segment.activeFocus ? 2 : 0; border.color: Theme.focus
                        }
                        Rectangle {
                            width: parent.width; height: DesktopTokens.px(4); radius: height / 2
                            color: segment.index === root.stepIndex ? root.mint
                                : segment.index < root.stepIndex ? Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.45)
                                : Theme.seam
                        }
                        Eyebrow {
                            visible: !root.compact
                            y: DesktopTokens.px(10)
                            width: parent.width
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            text: (segment.index < root.stepCount - 1 ? (segment.index + 1) + " " : "")
                                + root.stepNames[segment.modelData].toUpperCase()
                            color: segment.index === root.stepIndex ? root.mint
                                : segment.index < root.stepIndex ? Theme.label : DesktopTokens.textFaint
                        }
                    }
                }
            }
        }
        Flickable {
            id: pageScroll
            objectName: "onboardingScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            readonly property real pageMargin: DesktopTokens.px(root.compact ? 16 : 28)
            readonly property real gutter: DesktopTokens.px(root.compact ? 20 : 40)
            readonly property real balance: DesktopTokens.px(72)
            contentHeight: Math.max(height, pageBody.y + pageBody.implicitHeight + pageMargin)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            Column {
                id: pageBody
                objectName: "onboardingPageBody"
                width: Math.min(pageScroll.width - 2 * pageScroll.gutter, DesktopTokens.px(980))
                x: (pageScroll.width - width) / 2
                y: Math.max(pageScroll.pageMargin, (pageScroll.height - pageScroll.balance - implicitHeight) / 2)
                spacing: DesktopTokens.px(28)
                Column {
                    width: parent.width
                    spacing: DesktopTokens.px(12)
                    Row {
                        visible: root.step === "mode"
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: DesktopTokens.px(10)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: DesktopTokens.px(10); height: width; radius: width / 2; color: root.amber
                        }
                        Eyebrow {
                            text: qsTr("WELCOME TO THE OPENNOW BETA"); color: root.amber
                            font.pixelSize: DesktopTokens.px(11); lineHeight: DesktopTokens.px(14)
                        }
                    }
                    Text {
                        objectName: "onboardingHeading"
                        width: parent.width
                        text: root.titles[root.step]
                        color: Theme.label; font.family: Theme.displayFont
                        font.pixelSize: DesktopTokens.px(root.compact ? 38 : 56)
                        font.weight: Font.Black
                        font.letterSpacing: -DesktopTokens.px(root.compact ? 38 : 56) * 0.03
                        lineHeightMode: Text.FixedHeight
                        lineHeight: DesktopTokens.px(root.compact ? 44 : 60)
                        height: lineCount * lineHeight
                        topPadding: -DesktopTokens.px(7)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        Accessible.role: Accessible.Heading
                    }
                    Copy {
                        width: Math.min(parent.width, DesktopTokens.px(640))
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: root.introductions[root.step]
                    }
                }
                Loader {
                    id: stepLoader
                    objectName: "onboardingStepLoader"
                    width: parent.width
                    enabled: !root.saving
                    sourceComponent: ({mode: modePage, picture: picturePage, network: networkPage,
                        boost: boostPage, ready: readyPage})[root.step]
                }
                Rectangle {
                    visible: root.error !== ""
                    width: Math.min(parent.width, DesktopTokens.px(860))
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitHeight: errorLabel.implicitHeight + DesktopTokens.px(24)
                    radius: DesktopTokens.px(10)
                    color: Qt.rgba(root.coral.r,root.coral.g,root.coral.b,0.12)
                    border.color: root.coral
                    Text {
                        id: errorLabel
                        x: DesktopTokens.px(12); y: DesktopTokens.px(12)
                        width: parent.width - DesktopTokens.px(24)
                        text: root.error
                        color: root.coral; font.family: Theme.bodyFont
                        font.pixelSize: DesktopTokens.bodySize; wrapMode: Text.Wrap
                        Accessible.role: Accessible.AlertMessage
                    }
                }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: DesktopTokens.px(6)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: DesktopTokens.px(12)
                        Action {
                            objectName: "onboardingBack"
                            visible: root.stepIndex > 0
                            text: qsTr("Back")
                            enabled: !root.saving
                            onClicked: root.goToStep(root.stepIndex - 1)
                        }
                        Action {
                            objectName: "onboardingSkipBoost"
                            visible: root.step === "boost"
                            text: qsTr("Skip for now")
                            enabled: !root.saving
                            onClicked: root.skipBoost()
                        }
                        BusyIndicator {
                            visible: root.saving
                            running: root.saving && !AppController.reducedMotion
                            anchors.verticalCenter: parent.verticalCenter
                            width: DesktopTokens.px(28); height: width
                        }
                        Action {
                            id: nextButton
                            objectName: "onboardingNext"
                            primary: true
                            keyHint: root.compact ? "" : "ENTER"
                            leftPadding: DesktopTokens.px(22); rightPadding: DesktopTokens.px(root.compact ? 22 : 8)
                            width: Math.min(Math.max(implicitWidth, DesktopTokens.px(152)), pageBody.width)
                            text: root.saving ? qsTr("Saving…") : root.step === "ready" ? qsTr("Finish and open library")
                                : qsTr("Continue")
                            enabled: !root.saving
                            onClicked: root.next()
                        }
                    }
                    Action {
                        objectName: "onboardingReportBug"
                        visible: root.step === "mode"
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Something broken? Report a bug ↗")
                        implicitHeight: DesktopTokens.px(44)
                        flat: true
                        background: Rectangle {
                            radius: DesktopTokens.px(10); color: "transparent"
                            border.width: parent.activeFocus ? 2 : 0; border.color: Theme.focus
                        }
                        onClicked: Qt.openUrlExternally("https://github.com/OpenCloudGaming/OpenNOW/issues")
                    }
                }
                Card {
                    objectName: "onboardingSupport"
                    visible: root.step === "ready"
                    width: Math.min(parent.width, DesktopTokens.px(780))
                    anchors.horizontalCenter: parent.horizontalCenter
                    border.color: DesktopTokens.seamSoft
                    Item {
                        width: parent.width
                        height: Math.max(DesktopTokens.px(66), supportCopy.implicitHeight + DesktopTokens.px(28))
                        Rectangle {
                            x: DesktopTokens.px(18); anchors.verticalCenter: parent.verticalCenter
                            width: DesktopTokens.px(32); height: width; radius: DesktopTokens.px(9)
                            color: Qt.rgba(root.coral.r,root.coral.g,root.coral.b,0.14)
                            DesktopSettingsIcon { anchors.centerIn: parent; width: DesktopTokens.px(16); height: width; glyph: "heart"; ink: root.coral }
                        }
                        Column {
                            id: supportCopy
                            x: DesktopTokens.px(66); anchors.verticalCenter: parent.verticalCenter
                            width: sponsorButton.x - x - DesktopTokens.px(16)
                            spacing: DesktopTokens.px(2)
                            Copy { text: qsTr("OpenNOW is free and open source."); color: Theme.label; font.pixelSize: DesktopTokens.px(13); font.weight: Font.ExtraBold; lineHeight: DesktopTokens.px(17) }
                            Copy { text: qsTr("If it earns a place on your computer, you can sponsor development. No payment is collected in OpenNOW."); font.pixelSize: DesktopTokens.px(12); lineHeight: DesktopTokens.px(16) }
                        }
                        Action {
                            id: sponsorButton
                            objectName: "onboardingSponsor"
                            anchors.right: parent.right; anchors.rightMargin: DesktopTokens.px(14)
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Sponsor on GitHub ↗")
                            implicitHeight: DesktopTokens.px(38)
                            leftPadding: DesktopTokens.px(16); rightPadding: DesktopTokens.px(16)
                            onClicked: Qt.openUrlExternally("https://github.com/sponsors/zortos293")
                        }
                    }
                }
            }
        }
    }


    Component {
        id: modePage
        Column {
            spacing: DesktopTokens.px(28)
            GridLayout {
                width: parent.width
                columns: width >= DesktopTokens.px(680) ? 2 : 1
                columnSpacing: DesktopTokens.px(16); rowSpacing: DesktopTokens.px(16)
                DesktopOnboardingModeCard {
                    objectName: "onboardingDesktopMode"
                    Layout.fillWidth: true; Layout.fillHeight: true
                    selected: root.settings.launchInConsoleMode !== true
                    onClicked: root.store.setOnboardingSetting("launchInConsoleMode", false)
                }
                DesktopOnboardingModeCard {
                    objectName: "onboardingConsoleMode"
                    Layout.fillWidth: true; Layout.fillHeight: true
                    consoleMode: true; selected: root.settings.launchInConsoleMode === true
                    onClicked: root.store.setOnboardingSetting("launchInConsoleMode", true)
                }
            }
            DesktopSettingsPanel {
                width: parent.width
                paperStyle: true
                DesktopSettingsRow {
                    width: parent.width; paperStyle: true; glyph: "controller"
                    title: qsTr("Switch to console on gamepad input")
                    description: qsTr("Let controller input switch the shell after setup is complete.")
                    showDivider: false
                    DesktopSettingsToggle {
                        objectName: "onboardingSwitchOnPad"
                        checked: root.settings.switchToConsoleOnPad === true
                        Accessible.name: qsTr("Switch to console on gamepad input")
                        onValueChangedByUser: value => root.store.setOnboardingSetting("switchToConsoleOnPad", value)
                    }
                }
            }
        }
    }
    Component { id: picturePage; DesktopOnboardingPicture { store: root.store } }
    Component {
        id: networkPage
        Item {
            implicitHeight: networkCard.implicitHeight
            DesktopOnboardingNetwork {
                id: networkCard
                width: Math.min(parent.width, DesktopTokens.px(860))
                anchors.horizontalCenter: parent.horizontalCenter
                controller: root.store.onboardingAwdlController
            }
        }
    }
    Component { id: boostPage; DesktopOnboardingBoost { store: root.store } }

    Component {
        id: readyPage
        Item {
            implicitHeight: summaryCard.implicitHeight
            Card {
                id: summaryCard
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, DesktopTokens.px(780))
                CardHeading { text: qsTr("YOUR SETUP"); note: qsTr("READY TO SAVE") }
                Repeater {
                    model: [
                        {glyph:"controller",label:qsTr("Mode"),step:"mode",value:(root.settings.launchInConsoleMode === true ? qsTr("Console") : qsTr("Desktop"))
                            + (root.settings.switchToConsoleOnPad === true ? qsTr(" · switch on gamepad input") : "")},
                        {glyph:"monitor",label:qsTr("Picture"),step:"picture",value:qsTr("%1 · %2 FPS · %3 · %4 Mbps").arg(String(root.settings.resolution || "1920x1080").replace("x"," × "))
                            .arg(Number(root.settings.fps ?? 60) === 0 ? qsTr("Auto") : root.settings.fps ?? 60)
                            .arg(String(root.settings.codec || "auto").toUpperCase()).arg(root.settings.maxBitrateMbps ?? 75)},
                        ...(root.networkAvailable ? [{glyph:"globe",label:qsTr("Network"),step:"network",value:qsTr("Optional · configure in Settings")}] : []),
                        {glyph:"bolt",label:qsTr("Boost"),step:"boost",value:(root.settings.frameGeneration === "2x" ? qsTr("Frame generation 2× · Experimental") : qsTr("Frame generation off"))
                            + (Qt.platform.os === "osx" ? (root.settings.upscaling === "metalfx" ? qsTr(" · MetalFX · clarity %1 · noise reduction %2").arg(root.settings.upscalingSharpness ?? 10).arg(root.settings.upscalingDenoise ?? 0) : qsTr(" · upscaling off")) : (root.settings.upscaling === "fsr1" ? qsTr(" · FSR 1 · clarity %1").arg(root.settings.upscalingSharpness ?? 10) : qsTr(" · upscaling off")))}
                    ]
                    delegate: AbstractButton {
                        id: summaryRow
                        required property var modelData
                        readonly property int stepNumber: root.steps.indexOf(modelData.step)
                        width: parent.width
                        implicitHeight: Math.max(DesktopTokens.px(59), summaryValue.implicitHeight + DesktopTokens.px(26))
                        hoverEnabled: true
                        Accessible.name: qsTr("Edit %1").arg(modelData.label) + ": " + modelData.value
                        onClicked: root.goToStep(stepNumber)
                        background: Rectangle {
                            color: summaryRow.hovered || summaryRow.activeFocus ? DesktopTokens.raised : "transparent"
                            border.width: summaryRow.activeFocus ? 2 : 0; border.color: Theme.focus
                        }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: DesktopTokens.px(22); anchors.rightMargin: DesktopTokens.px(22)
                            spacing: DesktopTokens.px(16)
                            Rectangle {
                                visible: !root.compact
                                Layout.preferredWidth: DesktopTokens.px(32); Layout.preferredHeight: DesktopTokens.px(32)
                                radius: DesktopTokens.px(9); color: DesktopTokens.raised
                                DesktopSettingsIcon { anchors.centerIn: parent; width: DesktopTokens.px(16); height: width; glyph: summaryRow.modelData.glyph }
                            }
                            Eyebrow { Layout.preferredWidth: DesktopTokens.px(root.compact ? 60 : 76); text: summaryRow.modelData.label.toUpperCase(); color: Theme.textMuted }
                            Copy {
                                id: summaryValue
                                Layout.fillWidth: true; text: summaryRow.modelData.value
                                color: Theme.label; font.weight: Font.ExtraBold; lineHeight: DesktopTokens.px(20)
                            }
                            Eyebrow { text: "0" + (summaryRow.stepNumber + 1); color: Theme.textMuted; font.weight: Font.Medium }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: DesktopTokens.seamSoft }
                    }
                }
                Rectangle {
                    width: parent.width
                    implicitHeight: readyNote.implicitHeight + DesktopTokens.px(32)
                    color: DesktopTokens.seamSoft
                    Copy {
                        id: readyNote
                        x: DesktopTokens.px(22); y: DesktopTokens.px(16)
                        width: parent.width - DesktopTokens.px(44)
                        text: qsTr("Click any row to change it. Everything stays editable in Settings.")
                        font.pixelSize: DesktopTokens.px(12); lineHeight: DesktopTokens.px(16)
                    }
                }
            }
        }
    }
}
