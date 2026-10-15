import QtQuick
import OpenNOW

DesktopStreamControllersAcceptance {
    id: fixture
    property string flightState: argument("--flight-state", "connected")
    property int ticks: 0
    property Item streamBackdrop: Rectangle {
        parent: fixture.video ? fixture.video.parent : null
        visible: fixture.streamScene
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        z: -0.5
        gradient: Gradient {
            GradientStop { position: 0; color: "#1B3350" }
            GradientStop { position: 0.5; color: "#617A92" }
            GradientStop { position: 0.57; color: "#DDA66A" }
            GradientStop { position: 0.66; color: "#544130" }
            GradientStop { position: 1; color: "#181713" }
        }
    }
    readonly property bool streamScene: ["drawer-home", "drawer-controllers", "stats-expanded", "stream-clear", "badges"].includes(flightState)
    property QtObject badgeActiveInput: QtObject {
        readonly property var flightDevices: fixture.connectedFlights.slice(0, 2).map(device => Object.assign({}, device, {status: "active"}))
        readonly property bool forwardFlightControls: true
    }
    property QtObject badgeDeclinedInput: QtObject {
        readonly property var flightDevices: fixture.connectedFlights
        readonly property bool forwardFlightControls: true
    }
    property QtObject badgeOffInput: QtObject {
        readonly property var flightDevices: fixture.connectedFlights
        readonly property bool forwardFlightControls: false
    }
    property Item badgeHost: Rectangle {
        parent: fixture.parent
        visible: fixture.flightState === "badges"
        width: 960; height: 218; z: 1000
        gradient: Gradient {
            GradientStop { position: 0; color: "#1B3350" }
            GradientStop { position: 0.68; color: "#617A92" }
            GradientStop { position: 1; color: "#DDA66A" }
        }
        Repeater {
            model: [
                {title: "All forwarded", detail: "Mint · count of active devices"},
                {title: "Some not forwarded", detail: "Amber · active / detected"},
                {title: "None detected or forwarding off", detail: "No badge; bar unchanged"}
            ]
            delegate: Column {
                required property var modelData
                required property int index
                x: 32; y: 28 + index * 58; width: 190; spacing: 3
                Text { width: parent.width; text: parent.modelData.title; color: "white"; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.ExtraBold; wrapMode: Text.WordWrap }
                Text { text: parent.modelData.detail; color: "#B3FFFFFF"; font.family: Theme.bodyFont; font.pixelSize: 11 }
            }
        }
    }
    readonly property var connectedFlights: [
        {deviceId: "stick", name: "Thrustmaster HOTAS Warthog Joystick", type: "stick", vidPid: "044F:0402", status: "active"},
        {deviceId: "throttle", name: "Thrustmaster HOTAS Warthog Throttle", type: "throttle", vidPid: "044F:0404", status: "active"},
        {deviceId: "pedals", name: "Thrustmaster TPR Pendular Rudder", type: "pedals", vidPid: "044F:B68F", status: "declined"}
    ]

    function run(root) {
        check(["connected", "light-ready", "empty", "supported-expanded", "forwarding-off", "drawer-home",
            "drawer-controllers", "stats-expanded", "badges", "stream-clear"].includes(flightState), "known flight state")
        parent = root
        const owner = ShellStore.settingsOwnerState
        owner.coreClient = settingsClient
        owner.ready = true
        ShellStore.settings = Object.assign({}, ShellStore.settings, {
            appTheme: flightState === "light-ready" ? "light" : "dark", themePack: "aurora", themeAccentOverride: false,
            forwardFlightControls: flightState !== "forwarding-off", shortcutToggleStats: "F3",
            statsShowClock: false, statsShowRegion: flightState === "stats-expanded",
            statsShowJitter: false, sessionCounterEnabled: false, maxBitrateMbps: 75
        })
        owner.confirmedSettings = Object.assign({}, owner.settings)
        input.forwardFlightControls = flightState !== "forwarding-off"
        input.flightDevices = ["empty", "supported-expanded"].includes(flightState) ? [] : connectedFlights.map(device => Object.assign({}, device, {
            status: flightState === "light-ready" ? "ready" : flightState === "forwarding-off"
                ? "ignored" : device.status, player: 1
        }))
        if (flightState === "light-ready")
            input.flightDevices = input.flightDevices.slice(0, 2).concat([
                {deviceId: "wheel", name: "Logitech G923, PlayStation/PC", type: "wheel", vidPid: "046D:C266", status: "ready", player: 0}
            ])
        if (flightState === "forwarding-off")
            input.flightDevices = input.flightDevices.slice(0, 2).concat([
                {deviceId: "hotas", name: "Thrustmaster T.Flight Hotas One, PC mode", type: "stick", vidPid: "044F:B68D", status: "controller", player: 2}
            ])
        AppController.showOverlay("")
        if (!streamScene) return true
        ShellStore.streamerStartRequestId = sessionId
        ShellStore.streamInputPauseRequestId = sessionId
        ShellStore.selectedGame = {title: "Microsoft Flight Simulator", imageUrl: ""}
        ShellStore.activeSession = {sessionId: sessionId, phase: "ready", status: 2, regionName: "EU Frankfurt",
            streamProfile: {width: 2560, height: 1440, codec: "h265", colorQuality: "10bit_420", maxBitrateMbps: 75}}
        ShellStore.streamer = {status: "streaming", sessionId: sessionId, fps: 120, framesPerSecond: 120,
            pingMs: 14, receiveBitrateMbps: 42.6, bitrateMbps: 42.6, latencyMs: 38, decodeTimeMs: 2.1,
            firstFrameLatencyMs: 120, videoDropCount: 3,
            transport: "nvst", codec: "h265", mediaBackend: "vaapi"}
        ShellStore.streamState = "streaming"
        ShellStore.streamStartedAtMs = Date.now() - 4364000
        ShellStore.acceptNativeEvent({type: "telemetry", packetLossPercent: 0})
        video = need("streamSurfaceHost")
        if (flightState === "badges")
            ShellStore.settings = Object.assign({}, ShellStore.settings, {statsOverlayPosition: "top-left", statsShowTimer: false})
        return true
    }

    function advance() {
        ticks += 1
        if (flightState === "badges") {
            check(streamAlive(), "badge examples preserve the video item and session")
            const active = need("flightBadgeStats0")
            const declined = need("flightBadgeStats1")
            const off = need("flightBadgeStats2")
            check(active.flightVisible && active.activeFlightDevices.length === 2 && active.flightDevices.length === 2, "all-active compact badge")
            check(declined.flightVisible && declined.activeFlightDevices.length === 2 && declined.flightDevices.length === 3,
                "partially declined compact badge")
            check(!off.flightVisible && !off.featureBadges.some(badge => badge.glyph === "stick"), "forwarding-off hides the flight badge")
            for (const stats of [active, declined, off]) check(find(stats, "compactStatsBar").visible, "real compact bar is shown")
            return ticks < 12 ? 0 : 1
        }
        if (streamScene) {
            check(streamAlive(), "flight chrome preserves the same video item and session")
            if (ticks === 2 && flightState !== "stream-clear")
                AppController.showOverlay(flightState === "stats-expanded" ? "desktop-stream-stats-expanded" : "desktop-stream-menu")
            if (ticks === 6 && flightState === "drawer-controllers") need("streamControllersRow").clicked()
            if (ticks === 12) {
                if (flightState === "drawer-home") check(need("streamMenuDrawer").visible, "flight drawer is shown")
                if (flightState === "drawer-controllers") check(need("streamFlightDevices").visible, "real controller page lists flight devices")
                if (flightState === "stats-expanded") check(need("expandedStatsPanel").visible, "real expanded statistics are shown")
            }
            if (ticks === 14) AppController.showOverlay("")
            if (ticks === 17 && flightState !== "stream-clear")
                AppController.showOverlay(flightState === "stats-expanded" ? "desktop-stream-stats-expanded" : "desktop-stream-menu")
            if (ticks === 20 && flightState === "drawer-controllers") need("streamControllersRow").clicked()
            if (ticks < 26) return 0
            return 1
        }
        const panel = need("desktopFlightControlsPanel")
        if (ticks === 1) panel.supportedExpanded = flightState === "supported-expanded"
        if (ticks === 5) {
            const scroll = need("desktopSettingsContent")
            const previousRows = ["connected", "light-ready", "empty", "forwarding-off"].includes(flightState) ? 132 : 0
            scroll.contentY = Math.max(0, panel.mapToItem(scroll.contentItem, 0, 0).y - previousRows)
        }
        check(panel.forwarding === input.forwardFlightControls, "panel follows forwarding fixture")
        check(panel.devices.length === input.flightDevices.length, "panel follows device fixture")
        if (ticks < 12) return 0
        for (const device of input.flightDevices) {
            const badge = need("flightStatus-" + device.deviceId)
            check(badge.visible && badge.text === panel.statusText(device), "status badge is rendered for " + device.status)
        }
        return 1
    }
}
