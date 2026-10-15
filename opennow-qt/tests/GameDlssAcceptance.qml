import QtQuick
import QtQuick.Window
import OpenNOW

OwnershipAcceptance {
    id: root
    property var host: null
    property var modal: null
    property var scroll: null
    property int phase: 0
    property int key: 0
    property int modifiers: 0
    property bool settling: false
    onKeyChanged: if (key !== 0) settling = true
    property point click: Qt.point(-1, -1)
    onClickChanged: if (click.x >= 0) settling = true
    property int playCount: 0
    property real collapsedHeight: 0
    property Connections playObserver: Connections {
        target: root.modal
        function onPlayRequested() { root.playCount++ }
    }
    readonly property string shot: {
        const index = Qt.application.arguments.indexOf("--dlss-shot")
        return index >= 0 ? String(Qt.application.arguments[index + 1]) : ""
    }

    function expect(value, message) { if (!value) throw new Error("Game DLSS [" + phase + "]: " + message) }
    function title(id, name, dlss) {
        const value = {id:id, uuid:id, title:name, publisherName:"Fixture publisher", playabilityState:"PLAYABLE",
            selectedVariantIndex:0, availableStores:["STEAM"], isInLibrary:true,
            heroImageUrl:"qrc:/qt/qml/OpenNOW/res/brand/desktop-renew.jpg", imageUrl:"qrc:/qt/qml/OpenNOW/res/brand/desktop-renew.jpg",
            variants:[{id:id + "-steam", store:"STEAM", libraryStatus:"PLATFORM_SYNC", inLibrary:true, librarySelected:true,
                gfnStatus:"AVAILABLE", playStatus:"PLAYABLE"}]}
        if (dlss !== undefined) value.dlss = dlss
        return value
    }
    function listing(maxMultiplier) {
        return {superResolution:"native", frameGeneration:"native", multiFrameGeneration:{maxMultiplier:maxMultiplier},
            rayReconstruction:"native", dlaa:"override", source:"nvidia-rtx-games-list"}
    }
    readonly property var plain: title("dlss-plain", "No DLSS data", undefined)
    readonly property var cyberpunk: title("dlss-cyberpunk", "Cyberpunk 2077", listing(6))
    readonly property var tripled: title("dlss-tripled", "Three times", listing(3))
    readonly property var hades: title("dlss-hades", "Hades II", null)
    function capability(entitled, upsell) { return {entitled:entitled, upsell:upsell} }
    function plan(tier, overrides) { return {membershipTier:tier, dlssOverrides:overrides} }
    readonly property var ultimate: plan("ULTIMATE", {superResolution:capability(true, false), frameGeneration:capability(true, false),
        rayReconstruction:capability(true, false), frameGenerationMultipliers:[3, 4, 5, 6]})
    readonly property var ultimateTriple: plan("ULTIMATE", {superResolution:capability(true, false), frameGeneration:capability(true, false),
        rayReconstruction:capability(true, false), frameGenerationMultipliers:[3]})
    readonly property var performance: plan("PERFORMANCE", {superResolution:capability(true, false), frameGeneration:capability(true, true),
        rayReconstruction:capability(true, false), frameGenerationMultipliers:[]})
    readonly property var free: plan("FREE", {superResolution:capability(true, false), frameGeneration:capability(false, true),
        rayReconstruction:capability(false, true), frameGenerationMultipliers:[]})
    readonly property var features: ["superResolution", "frameGeneration", "rayReconstruction", "dlaa"]

    function signIn(subscription) {
        ShellStore.authSession = {user:{userId:"dlss-user", displayName:"DLSS fixture"}, provider:{idpId:"fixture-provider", code:"NVIDIA"}}
        ShellStore.subscription = subscription
    }
    function show(game) { ShellStore.selectedGame = game }
    function polishLayout(item) {
        item.ensurePolished()
        for (const child of item.children || []) polishLayout(child)
        item.ensurePolished()
    }
    function chipSet() {
        return features.map(key => find(modal, "gameDlssChip-" + key)).filter(chip => chip && chip.visible).map(chip => {
            const icon = find(chip, "gameDlssChipIcon")
            return (icon.visible ? (icon.glyph === "check" ? "✓" : icon.glyph === "lock" ? "🔒" : "?") : "") + chip.label
        })
    }
    function row(key) { return find(modal, "gameDlssRow-" + key) }
    function tiers(key) { return [0, 1, 2].map(index => find(row(key), "gameDlssTier-" + key + "-" + index).tierState) }
    function same(actual, expected, message) {
        expect(JSON.stringify(actual) === JSON.stringify(expected), message + ": " + JSON.stringify(actual))
    }
    function panel() { return find(modal, "gameDlssPanel") }
    function within(item, bounds, message) {
        const top = item.mapToItem(bounds, 0, 0)
        expect(item.visible && item.width > 0 && item.height > 0, message + " has no size: " + [item.width, item.height])
        expect(top.x >= -0.5 && top.y >= -0.5 && top.x + item.width <= bounds.width + 0.5 && top.y + item.height <= bounds.height + 0.5,
            message + " lies outside its container: " + [top.x, top.y, item.width, item.height, bounds.width, bounds.height])
    }
    function clickOn(item) {
        const center = item.mapToItem(host, item.width / 2, item.height / 2)
        click = Qt.point(center.x, center.y)
    }
    function strip() { return find(modal, "gameDlssStrip") }
    function fits() {
        const dialog = find(modal, "gameDetailsDialog")
        expect(modal.width === 1600 && modal.height === 900, "the fixture window is not 1600×900: " + [modal.width, modal.height])
        expect(dialog.height <= modal.maximumDialogHeight + 0.5 && modal.maximumDialogHeight <= 836,
            "the details window exceeds its height cap: " + [dialog.height, modal.maximumDialogHeight])
        expect(scroll.contentHeight <= scroll.height + 0.5 || scroll.contentHeight > dialog.height - 0.5,
            "content past the cap does not scroll")
        const box = panel()
        expect(box.visible && box.width > 0, "the expanded panel is hidden")
        within(find(modal, "gameDlssOverridesLink"), box, "the DLSS overrides link")
        within(find(modal, "gameDlssToggle"), find(modal, "gameDetailsHero"), "the details toggle")
        const bottom = box.mapToItem(scroll, 0, box.height).y
        expect(bottom <= scroll.height + 0.5, "the expanded panel is cut off at the top of the window: " + [bottom, scroll.height])
        for (const key of features) {
            const item = row(key)
            if (!item || !item.visible) continue
            const edge = item.mapToItem(box, item.width, item.height)
            expect(edge.x <= box.width + 0.5 && edge.y <= box.height + 0.5, key + " overflows the panel")
        }
    }

    function run(windowHost) {
        host = windowHost
        ShellStore.settings = Object.assign({}, ShellStore.settings, {onboardingCompleted:true, desktopUiScale:1,
            resolution:"1920x1080", fps:60, codec:"h264"})
        DesktopTokens.uiScale = 1
        ShellStore.authGeneration = 42
        signIn(ultimate)
        ShellStore.nativeRuntimeReady = true
        const owner = ShellStore.catalogOwnerState
        owner.resetCloudActions()
        owner.catalogGames = [plain, cyberpunk, tripled, hades]
        owner.catalogState = "ready"
        owner.catalogComplete = true
        show(plain)
        AppController.navigate("game-detail")
        bindDetail(host)
        detail("ready")
        modal = find(host, "desktopGameModal")
        scroll = find(modal, "gameDetailsScroll")
        return true
    }

    function advance() {
        polishLayout(modal)
        if (settling) {
            settling = false
            return 0
        }
        const steps = [measureWithoutData, collapsedUltimate, expandedUltimate, ultimateFocus, multiplierCaps,
            performancePlan, performanceFocus, freePlan, collapseByKey, expandByKey, notListed, unknownSupport, signedOut, closeDetails, reopenDetails, openOverrides,
            prepareScreenshot, finish]
        return steps[phase++]()
    }

    function measureWithoutData() {
        expect(modal.opened, "details did not open")
        const chips = find(modal, "gameDlssChips")
        expect(!chips.visible, "a game without DLSS data shows a DLSS row: " + [chips.info.listed, chips.info.notListed, JSON.stringify(modal.game && modal.game.dlss)])
        collapsedHeight = find(modal, "gameDetailsHero").height
        show(cyberpunk)
        return 0
    }
    function collapsedUltimate() {
        expect(find(modal, "gameDlssChips").visible, "the DLSS row is missing")
        same(chipSet(), ["✓SR", "✓MFG 4×", "✓RR", "✓DLAA"], "Ultimate chips")
        expect(find(modal, "gameDlssPlanCaption").text === "on your plan", "the caption does not say on your plan")
        const toggle = find(modal, "gameDlssToggle")
        expect(toggle.text === "What you get" && !modal.dlssExpanded && !panel().visible, "details are not collapsed by default")
        expect(Math.abs(find(modal, "gameDetailsHero").height - collapsedHeight) <= 0.5,
            "the collapsed row grew the window: " + [find(modal, "gameDetailsHero").height, collapsedHeight])
        within(toggle, find(modal, "gameDetailsHero"), "the collapsed toggle")
        clickOn(toggle)
        return 0
    }
    function expandedUltimate() {
        expect(modal.dlssExpanded && panel().visible, "clicking the toggle did not expand the details")
        expect(playCount === 0, "clicking the toggle started the game")
        expect(find(modal, "gameDlssToggle").text === "Hide", "the toggle does not read Hide")
        expect(row("frameGeneration").source === "IN GAME · 6×" && row("dlaa").source === "OVERRIDE", "source tags are wrong")
        expect(row("superResolution").answer === "Included · Upgrades the game's DLSS model", "the SR answer is wrong")
        expect(row("frameGeneration").answer === "Up to 4× · Plus model preset · NVIDIA lists 6×, GeForce NOW caps at 4×",
            "the MFG answer is not capped at 4×: " + row("frameGeneration").answer)
        same(tiers("superResolution"), ["available", "available", "included"], "SR ladder on Ultimate")
        same(tiers("frameGeneration"), ["unavailable", "available", "included"], "FG ladder on Ultimate")
        same(tiers("rayReconstruction"), ["unavailable", "available", "included"], "RR ladder on Ultimate")
        expect(!strip().visible, "Ultimate with MFG shows an upgrade strip")
        fits()
        key = Qt.Key_Tab
        return 0
    }
    function ultimateFocus() {
        expect(find(modal, "gameDlssOverridesLink").activeFocus, "Tab from the toggle did not reach the DLSS overrides link")
        signIn(ultimateTriple)
        return 0
    }
    function multiplierCaps() {
        same(chipSet(), ["✓SR", "✓MFG 3×", "✓RR", "✓DLAA"], "a 3× entitlement")
        expect(row("frameGeneration").answer === "Up to 3× · Plus model preset · NVIDIA lists 6×, GeForce NOW caps at 3×",
            "the 3× entitlement answer is wrong: " + row("frameGeneration").answer)
        signIn(ultimate)
        show(tripled)
        polishLayout(modal)
        same(chipSet(), ["✓SR", "✓MFG 3×", "✓RR", "✓DLAA"], "a game NVIDIA lists at 3×")
        expect(row("frameGeneration").answer === "Up to 3× · Plus model preset", "the 3× game answer is wrong")
        show(cyberpunk)
        signIn(performance)
        return 0
    }
    function performancePlan() {
        same(chipSet(), ["✓SR", "✓FG preset", "✓RR", "✓DLAA"], "Performance chips")
        expect(row("frameGeneration").answer === "Model preset · No multiplier on your plan", "the Performance FG answer is wrong")
        same(tiers("frameGeneration"), ["unavailable", "included", "available"], "FG ladder on Performance")
        same(tiers("dlaa"), ["available", "included", "available"], "DLAA ladder on Performance")
        expect(strip().visible && strip().text === "Ultimate adds Multi Frame Generation up to 4× on RTX 5080 rigs."
            && find(strip(), "gameDlssStripAction").text === "See memberships", "the Performance upgrade strip is wrong")
        fits()
        find(modal, "gameDlssToggle").forceActiveFocus()
        key = Qt.Key_Tab
        return 0
    }
    function performanceFocus() {
        expect(find(modal, "gameDlssStripAction").activeFocus, "Tab from the toggle did not reach See memberships")
        signIn(free)
        return 0
    }
    function freePlan() {
        same(chipSet(), ["✓SR", "🔒Frame Gen", "🔒RR", "✓DLAA"], "Free chips")
        expect(row("frameGeneration").answer === "Not on Free · Preset on Performance · 4× on Ultimate", "the Free FG answer is wrong")
        expect(row("rayReconstruction").answer === "Not on Free · Performance and Ultimate", "the Free RR answer is wrong")
        same(tiers("superResolution"), ["included", "available", "available"], "SR ladder on Free")
        same(tiers("frameGeneration"), ["missing", "available", "available"], "FG ladder on Free")
        same(tiers("rayReconstruction"), ["missing", "available", "available"], "RR ladder on Free")
        expect(strip().visible && strip().text === "Performance adds RR and the FG preset. Ultimate adds MFG up to 4×.",
            "the Free upgrade strip is wrong")
        fits()
        find(modal, "gameDlssToggle").forceActiveFocus()
        key = Qt.Key_Return
        return 0
    }
    function collapseByKey() {
        expect(!modal.dlssExpanded && !panel().visible, "Return on the toggle did not collapse the details")
        expect(playCount === 0, "Return on the toggle started the game")
        key = Qt.Key_Return
        return 0
    }
    function expandByKey() {
        expect(modal.dlssExpanded && panel().visible, "Return on the toggle did not expand the details")
        show(hades)
        return 0
    }
    function notListed() {
        expect(find(modal, "gameDlssNotListedChip").visible && chipSet().length === 0, "the not-listed chip is wrong")
        expect(!find(modal, "gameDlssPlanCaption").visible, "the not-listed row shows a plan caption")
        expect(find(modal, "gameDlssNotListedCard").visible
            && find(modal, "gameDlssNotListedTitle").text === "Hades II isn't on NVIDIA's DLSS list", "the not-listed card is wrong")
        expect(!strip().visible && find(modal, "gameDlssOverridesLink").visible, "the not-listed panel has the wrong actions")
        fits()
        show(plain)
        return 0
    }
    function unknownSupport() {
        expect(modal.dlssExpanded, "the expanded state was lost")
        expect(!find(modal, "gameDlssChips").visible && !panel().visible && !find(modal, "gameDlssNotListedChip").visible,
            "a game without a dlss key shows DLSS support or claims it is not on NVIDIA's list")
        show(cyberpunk)
        ShellStore.authSession = null
        ShellStore.subscription = null
        return 0
    }
    function signedOut() {
        expect(modal.opened, "signing out closed details")
        same(chipSet(), ["SR", "MFG 6× in list", "RR", "DLAA"], "signed-out chips")
        expect(find(modal, "gameDlssPlanCaption").text === "per NVIDIA's list", "the signed-out caption is wrong")
        expect(row("superResolution").answer === "Every plan" && row("rayReconstruction").answer === "Performance and Ultimate"
            && row("frameGeneration").answer === "Preset on Performance · MFG up to 4× on Ultimate", "signed-out answers are not tier-neutral")
        for (const key of features)
            expect(tiers(key).every(state => state === "available" || state === "unavailable"), key + " highlights a tier while signed out")
        same(tiers("frameGeneration"), ["unavailable", "available", "available"], "FG ladder signed out")
        expect(strip().visible && strip().text === "Sign in to see your plan highlighted."
            && find(strip(), "gameDlssStripAction").text === "Sign in", "the sign-in strip is wrong")
        fits()
        signIn(null)
        polishLayout(modal)
        expect(!strip().visible && find(modal, "gameDlssPlanCaption").text === "per NVIDIA's list",
            "a signed-in account without entitlements is treated as a plan")
        signIn(ultimate)
        find(modal, "desktopGamePlay").forceActiveFocus()
        key = Qt.Key_Escape
        return 0
    }
    function closeDetails() {
        expect(!modal.opened, "Escape did not close details")
        AppController.navigate("game-detail")
        detail("ready")
        return 0
    }
    function reopenDetails() {
        expect(modal.opened && modal.dlssExpanded && panel().visible, "the expanded state was not kept for the session")
        expect(Object.keys(ShellStore.settings).every(name => name.indexOf("Expanded") < 0), "the expanded state was persisted")
        clickOn(find(modal, "gameDlssOverridesLink"))
        return 0
    }
    function openOverrides() {
        expect(AppController.route === "settings-streaming", "clicking the DLSS overrides link did not open Stream settings")
        expect(playCount === 0, "a DLSS control started the game")
        if (!shot)
            return 0
        const states = {ultimate:[ultimate, cyberpunk], performance:[performance, cyberpunk], free:[free, cyberpunk], "not-listed":[ultimate, hades]}
        expect(states[shot], "unknown --dlss-shot " + shot)
        signIn(states[shot][0])
        show(states[shot][1])
        AppController.navigate("game-detail")
        detail("ready")
        return 0
    }
    function prepareScreenshot() {
        expect(!shot || (modal.opened && panel().visible), "the screenshot state is not expanded")
        if (shot) fits()
        return 0
    }
    function finish() { return 1 }
}
