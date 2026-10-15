import QtQuick
import OpenNOW

QtObject {
    property var surface: null
    property var window: null
    property bool initialInput: false
    property string initialOverlay: ""
    property string initialRoute: ""

    property QtObject settingsClient: QtObject {
        property int serial: 0
        property var writes: []
        function request(method, params, timeout) {
            if (method !== "settings.set") return ""
            writes = writes.concat([params])
            return "hdr-downgrade-setting-" + (++serial)
        }
        function cancel(id) {}
    }

    function check(ok, message) {
        if (!ok) throw new Error("HDR downgrade acceptance: " + message)
    }

    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }

    function toast() {
        const item = find(window.contentItem, "streamHdrDowngradeToast")
        check(item !== null, "the HDR toast is part of the stream toast stack")
        return item
    }

    function session(id, gameId, variantId, title, downgrade) {
        ShellStore.selectedGame = {id: gameId, title: title, imageUrl: ""}
        ShellStore.activeSession = {sessionId: id, appId: variantId, catalogAppId: gameId,
            phase: "ready", status: 2, hdrDowngrade: downgrade,
            negotiatedStreamProfile: {colorQuality: "8bit_420", bitDepth: 8, chromaFormat: 0,
                enableHdr: false, enableHdrSource: "request"}}
        ShellStore.streamer = {status: "streaming", sessionId: id}
        ShellStore.streamState = "streaming"
        ShellStore.streamerStopExpected = false
        ShellStore.streamStopRequestId = ""
    }

    function firstFrame() {
        ShellStore.acceptNativeEvent({type: "status", event: "first-frame", status: "streaming"})
    }

    function shown() {
        return ShellStore.settings.hdrNoticeShownGameIds || []
    }

    function assertUndisturbed(message) {
        check(find(window.contentItem, "streamSurfaceHost") === surface && surface.visible,
            message + ": the same video surface stays visible")
        check(!toast().activeFocus && window.activeFocusItem === surface,
            message + ": the notice does not take keyboard focus from gameplay")
        check(surface.inputEnabled === initialInput && AppController.overlay === initialOverlay
            && AppController.route === initialRoute, message + ": gameplay routing is unchanged")
        check(ShellStore.streamer.status === "streaming", message + ": media remains streaming")
        const stats = find(window.contentItem, "desktopStreamStats")
        check(stats && stats.videoText.indexOf("HDR") < 0, message + ": statistics report the SDR session")
    }

    function run(parent) {
        window = parent.Window.window
        ShellStore.streamerStartRequestId = "fixture-blocked"
        ShellStore.streamInputPauseRequestId = "fixture-blocked"
        const owner = ShellStore.settingsOwnerState
        ShellStore.settings = Object.assign({}, ShellStore.settings, {enableHdr: true, hdrNoticeShownGameIds: []})
        owner.confirmedSettings = Object.assign({}, owner.settings)
        owner.coreClient = settingsClient
        owner.ready = true

        session("warm-up", "portal-2", "620", "Portal 2", null)
        firstFrame()
        surface = find(parent, "streamSurfaceHost")
        check(surface && surface.visible, "stream surface is alive before the notice")
        check(!toast().visible && shown().length === 0, "a session without a downgrade stays silent")
        session("downgraded-a", "doom-eternal", "1001", "DOOM Eternal", "game-unsupported")
        initialInput = surface.inputEnabled
        initialOverlay = AppController.overlay
        initialRoute = AppController.route
        check(!toast().visible && ShellStore.streamHdrNotice === null, "nothing shows before the first frame")
        firstFrame()
        check(toast().visible && toast().width > 0 && toast().height > 0,
            "the first downgraded session shows the toast")
        check(toast().title === "Streaming in SDR"
            && toast().subtitle === "DOOM Eternal doesn't support HDR. Your HDR setting stays on.",
            "the toast names the game and keeps the HDR setting on")
        check(shown().length === 1 && shown()[0] === "doom-eternal",
            "the parent game, not the store version, is remembered as shown")
        check(ShellStore.settings.enableHdr === true
            && settingsClient.writes.every(write => write.key !== "enableHdr"), "the HDR preference is untouched")
        assertUndisturbed("first notice")
        firstFrame()
        check(settingsClient.writes.length === 1, "recovery frames do not record the game again")

        session("downgraded-a-again", "doom-eternal", "1001", "DOOM Eternal", "game-unsupported")
        firstFrame()
        check(!toast().visible && ShellStore.streamHdrNotice === null, "the same game does not show the toast again")

        session("downgraded-a-xbox", "doom-eternal", "2002", "DOOM Eternal", "game-unsupported")
        firstFrame()
        check(!toast().visible && ShellStore.streamHdrNotice === null && shown().length === 1,
            "another store version of the same game does not show the toast again")

        session("downgraded-unknown-game", "", "3003", "Unknown game", "game-unsupported")
        firstFrame()
        check(!toast().visible && ShellStore.streamHdrNotice === null && shown().length === 1,
            "a session without a catalog game identity shows nothing")

        session("hdr-supported", "cyberpunk-2077", "1002", "Cyberpunk 2077", null)
        firstFrame()
        check(!toast().visible && ShellStore.streamHdrNotice === null, "no toast when hdrDowngrade is null")

        const history = []
        for (let index = 0; index < 199; ++index) history.push("old-" + index)
        history.push("doom-eternal")
        ShellStore.settings = Object.assign({}, ShellStore.settings, {hdrNoticeShownGameIds: history})
        session("downgraded-b", "counter-strike-2", "730", "Counter-Strike 2", "game-unsupported")
        firstFrame()
        check(toast().visible
            && toast().subtitle === "Counter-Strike 2 doesn't support HDR. Your HDR setting stays on.",
            "a different game shows the toast")
        check(shown().length === 200 && shown()[0] === "old-1" && shown()[199] === "counter-strike-2"
            && shown().indexOf("doom-eternal") >= 0, "the bounded history evicts the oldest game")
        assertUndisturbed("second game")
        return true
    }

    function verifyRendered(parent) {
        check(toast().visible, "the toast is still rendered after composition")
        assertUndisturbed("rendered")
        return true
    }
}
