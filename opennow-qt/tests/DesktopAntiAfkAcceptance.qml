import QtQuick
import OpenNOW

QtObject {
    id: fixture
    function check(ok, message) { if (!ok) throw new Error("Desktop Anti-AFK: " + message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    function useSettings(values) {
        ShellStore.settings = Object.assign({}, ShellStore.settings, values)
    }
    function startSession() {
        ShellStore.activeSession = {sessionId: "anti-afk-fixture", phase: "ready", status: 2}
        ShellStore.streamer = {status: "streaming", sessionId: "anti-afk-fixture", firstFrameLatencyMs: 37}
        ShellStore.streamState = "streaming"
        ShellStore.streamStartedAtMs = Date.now() - 754000
    }
    function run(parent) {
        ShellStore.streamerStartRequestId = "anti-afk-fixture"
        ShellStore.streamInputPauseRequestId = "anti-afk-fixture"
        useSettings({showAntiAfkIndicator: true, antiAfkReminderEveryMinutes: 15,
                     antiAfkReminderDurationSeconds: 5})
        startSession()
        check(!ShellStore.antiAfkEnabled, "sessions start with Anti-AFK off")

        AppController.showOverlay("desktop-stream-menu")
        const toggle = find(parent, "streamAntiAfkControl")
        check(toggle !== null && toggle.visible && toggle.enabled, "the Ctrl+G menu offers an Anti-AFK row")
        check(toggle.stateText === qsTr("Off") && !toggle.checked, "the row reports Off")
        toggle.activated()
        check(ShellStore.antiAfkEnabled && toggle.stateText === qsTr("On") && toggle.checked,
            "the menu row turns Anti-AFK on through ShellStore")
        check(AppController.overlay === "desktop-stream-menu", "toggling keeps the menu open")
        check(ShellStore.antiAfkPulseTimer.running, "the single ShellStore pulse timer owns the live pulse")
        toggle.activated()
        check(!ShellStore.antiAfkEnabled && toggle.stateText === qsTr("Off"), "the menu row turns Anti-AFK off")
        check(!ShellStore.antiAfkPulseTimer.running, "turning Anti-AFK off stops the pulse")

        const video = find(parent, "streamSurfaceHost")
        check(video !== null, "the desktop stream item is mounted")
        check(video.shortcutBindings["toggle-anti-afk"][0] === "Ctrl+Shift+K",
            "the default Anti-AFK shortcut reaches the desktop stream item")
        useSettings({shortcutToggleAntiAfk: "Ctrl+Alt+J"})
        check(video.shortcutBindings["toggle-anti-afk"][0] === "Ctrl+Alt+J",
            "a rebinding reaches the desktop stream item")

        AppController.showOverlay("")
        video.localShortcutRequested("toggle-anti-afk")
        check(ShellStore.antiAfkEnabled && ShellStore.streamControlMessage === qsTr("Anti-AFK on"),
            "the desktop shortcut flips the same ShellStore state")
        const toast = find(parent, "streamAntiAfkToast")
        check(toast !== null && toast.visible && toast.title === qsTr("Anti-AFK on"),
            "the shortcut shows desktop feedback")
        const indicator = find(parent, "desktopAntiAfkIndicator")
        check(indicator !== null && indicator.visible, "the indicator shows while Anti-AFK is on")
        AppController.showOverlay("desktop-stream-stats")
        check(!indicator.visible, "the indicator yields to the statistics overlay like the session clock")
        AppController.showOverlay("")
        check(indicator.visible, "the indicator returns when statistics close")

        useSettings({showAntiAfkIndicator: false})
        check(!ShellStore.antiAfkIndicatorShown(899) && ShellStore.antiAfkIndicatorShown(900)
            && ShellStore.antiAfkIndicatorShown(904) && !ShellStore.antiAfkIndicatorShown(905),
            "a hidden indicator returns only for the reminder window")
        useSettings({showAntiAfkIndicator: true})

        video.localShortcutRequested("toggle-anti-afk")
        check(!ShellStore.antiAfkEnabled && toast.title === qsTr("Anti-AFK off") && !indicator.visible,
            "the shortcut turns Anti-AFK off with feedback")

        video.localShortcutRequested("toggle-anti-afk")
        ShellStore.activeSession = null
        check(!ShellStore.antiAfkEnabled && !ShellStore.antiAfkPulseTimer.running,
            "ending the session turns Anti-AFK off")

        startSession()
        useSettings({shortcutToggleAntiAfk: "Ctrl+Shift+K"})
        ShellStore.applyStreamShortcutAction("toggle-anti-afk")
        AppController.showOverlay(Qt.application.arguments.indexOf("--anti-afk-menu") >= 0
            ? "desktop-stream-menu" : "")
        return true
    }
}
