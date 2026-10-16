import QtQuick
import OpenNOW

// A notice that arrives when the stack already cannot fit must stay pending: held hidden it
// must not be presented, must not start its display lifetime, and must not be recorded as
// shown. The colour notice is raised first so it is presented and consumed legitimately, then
// the HDR notice arrives into a stack that no longer fits. Packet loss is fed throughout, and it
// is unstable for the second half of the hold, so a claim taken while the stack is hidden would
// suppress the notice for the rest of the episode. The hold stays inside the colour notice's
// lifetime, because the stack genuinely fits again once that toast expires.
QtObject {
    id: fixture
    property int key: 0
    property int modifiers: 0
    property int tick: 0
    property bool released: false
    property Item parent: null
    property Item video: null
    property var window: null
    property int hiddenTicks: 140
    property int lossFeedTicks: 10

    property QtObject settingsClient: QtObject {
        property int serial: 0
        function request(method, params, timeout) {
            return method === "settings.set" ? "stream-toast-pending-setting-" + (++serial) : ""
        }
        function cancel(id) {}
    }

    function require(condition, message) {
        if (!condition) throw new Error("Stream toast pending: " + message)
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

    function column() {
        const item = find(window.contentItem, "desktopStreamToasts")
        require(item !== null, "the stream toast column is in the tree")
        return item
    }

    function shown() {
        return ShellStore.settings.hdrNoticeShownGameIds || []
    }

    function health() {
        return ShellStore.connectionHealth
    }

    function feedLoss() {
        ShellStore.acceptNativeEvent({type: "telemetry", sessionId: "stream-toast-pending",
            packetLossPercent: 1.5})
    }

    function run(parent) {
        window = parent.Window.window
        fixture.parent = parent
        ShellStore.streamerStartRequestId = "fixture-blocked"
        ShellStore.streamInputPauseRequestId = "fixture-blocked"
        const owner = ShellStore.settingsOwnerState
        ShellStore.settings = Object.assign({}, ShellStore.settings,
            {enableHdr: true, hdrNoticeShownGameIds: []})
        owner.confirmedSettings = Object.assign({}, owner.settings)
        owner.coreClient = settingsClient
        owner.ready = true
        const title = "Hollow Knight: Silksong — Collector's Edition Deluxe Bundle (Pre-Order)"
        ShellStore.selectedGame = {id: "hollow-knight-silksong", title: title, imageUrl: ""}
        ShellStore.activeSession = {sessionId: "stream-toast-pending", appId: "9001",
            catalogAppId: "hollow-knight-silksong", phase: "ready", status: 2,
            hdrDowngrade: "game-unsupported",
            negotiatedStreamProfile: {colorQuality: "8bit_420", bitDepth: 8, chromaFormat: 0,
                enableHdr: false, enableHdrSource: "request"}}
        ShellStore.streamer = {status: "streaming", sessionId: "stream-toast-pending"}
        ShellStore.streamState = "streaming"
        ShellStore.streamerStopExpected = false
        ShellStore.streamStopRequestId = ""
        ShellStore.streamColorNotice = null
        ShellStore.streamColorNoticeShown = false
        video = find(parent, "streamSurfaceHost")
        require(video && video.visible, "the stream surface is alive")
        ShellStore.streamColorNotice = {sessionId: "stream-toast-pending", source: "server",
            actualColorQuality: "8bit_420", requestedColorQuality: "10bit_444",
            receivedAtMs: Date.now()}
        require(ShellStore.streamColorNoticeShown === true,
            "the colour notice fits on its own and is presented first")
        ShellStore.acceptNativeEvent({type: "status", event: "first-frame", status: "streaming"})
        return true
    }

    function assertPending() {
        const toasts = column()
        if (tick % 20 === 1)
            console.log("PENDING_STATE tick=" + tick + " visible=" + toasts.visible
                + " pending=" + toasts.pendingNotices + " stack=" + toasts.stackHeight
                + " hdr=" + toasts.hdrNotice + " hdrLife=" + toasts.hdrLifetime
                + " loss=" + toasts.lossNotice + " lossLife=" + toasts.lossLifetime
                + " lossStatus=" + health().status + " lastNoticeAt=" + health().lastNoticeAt
                + " y=" + toasts.y + " shown=" + JSON.stringify(shown()))
        require(toasts.visible === false, "a stack that cannot fit stays hidden")
        require(toasts.hdrNotice === true, "the HDR notice is still queued")
        require(toasts.hdrLifetime === 0, "the HDR display lifetime has not started")
        require(shown().length === 0, "the game is not recorded as shown while it is unseen")
        require(health().lastNoticeAt === null,
            "the loss claim is not consumed while the stack is hidden")
        require(toasts.lossNotice === false, "the loss notice is not raised while the stack is hidden")
        require(toasts.lossLifetime === 0, "the loss display lifetime has not started")
        if (tick > lossFeedTicks * 10)
            require(health().status === "unstable",
                "the loss is sustained, so a claim would be taken if the stack were shown")
    }

    function assertPresented() {
        const toasts = column()
        require(toasts.visible === true, "the stack shows once the overlay frees the space")
        const toast = find(window.contentItem, "streamHdrDowngradeToast")
        require(toast !== null && toast.visible, "the HDR notice is presented")
        require(shown().length === 1 && shown()[0] === "hollow-knight-silksong",
            "the game is recorded once, after it is presented")
        require(health().lastNoticeAt !== null,
            "the loss claim is taken once the stack is shown")
        const lossToast = find(window.contentItem, "streamPacketLossToast")
        require(lossToast !== null && lossToast.visible, "the loss notice is presented")
    }

    function advance() {
        ++tick
        if (!released) {
            assertPending()
            if (tick % lossFeedTicks === 1) feedLoss()
            if (tick < hiddenTicks) return 0
            assertPending()
            require(AppController.showOverlay("") === true, "the stats overlay closes")
            feedLoss()
            released = true
            return 0
        }
        assertPresented()
        return 1
    }

    function verifyRendered(parent) {
        assertPresented()
        return true
    }
}
