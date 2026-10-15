import QtQuick
import OpenNOW

QtObject {
    function check(value, message) { if (!value) throw new Error("Game labels: " + message) }
    function collect(item, name, found) {
        if (item.objectName === name) found.push(item)
        for (const child of item.children || []) collect(child, name, found)
        return found
    }
    function labelsFor(host, id) {
        return collect(host, "desktopGameLabels", []).find(item => item.game && item.game.id === id && item.visible)
    }
    function child(item, name) { return collect(item, name, [])[0] }
    function polish(item) {
        for (const nested of item.children || []) polish(nested)
        if (typeof item.forceLayout === "function") item.forceLayout()
    }
    function variant(id, store, owned, features) {
        return {id:id, store:store, libraryStatus:owned ? "PLATFORM_SYNC" : "NOT_OWNED", inLibrary:owned,
            gfnStatus:"AVAILABLE", playStatus:owned ? "PLAYABLE" : "UNKNOWN", features:features || []}
    }
    function game(id, title, variants, extra) {
        return Object.assign({id:id, uuid:id, title:title, playabilityState:"PLAYABLE", selectedVariantIndex:0,
            isInLibrary:true, availableStores:variants.map(item => item.store),
            imageUrl:"qrc:/qt/qml/OpenNOW/res/brand/desktop-renew.jpg", variants:variants}, extra || {})
    }
    readonly property var crowded: game("labels-crowded", "Four launchers", [
        variant("101", "Steam", false, ["rtx"]),
        variant("102", "Epic Games Store", false, ["hdr", "dlss"]),
        variant("103", "GOG", true, ["reflex"]),
        variant("104", "Xbox", false),
        variant("105", "Battle.net", false),
        variant("106", "Steam", false)])
    readonly property var locked: game("labels-locked", "Paid membership", [variant("201", "Steam", true)],
        {requiresPaidMembership:true, membershipTierLabel:"Premium"})
    readonly property var plain: game("labels-plain", "No labels", [variant("301", "Unknown", false)])

    function lockedFor(tier) {
        ShellStore.subscription = tier === null ? null : {membershipTier:tier}
        return ShellStore.gameLockedByMembership(locked)
    }

    function run(host) {
        const launchers = ConsoleStores.launchers(crowded)
        check(launchers.length === 5, "duplicate stores were not merged")
        check(launchers[0].store === "GOG" && launchers[0].owned && !launchers.slice(1).some(item => item.owned),
            "the owned launcher does not lead")
        check(JSON.stringify(launchers.slice(1).map(item => item.store)) === JSON.stringify(["Steam", "Epic Games Store", "Xbox", "Battle.net"]),
            "unowned launchers lost catalog order")
        check(JSON.stringify(DesktopTokens.gameFeatures(crowded)) === JSON.stringify(["rtx", "hdr", "reflex"]),
            "features are not the data-backed set in fixed order")
        check(DesktopTokens.gameFeatures(plain).length === 0 && ConsoleStores.launchers(plain).length === 0,
            "a game without catalog data shows labels")

        ShellStore.authSession = {user:{userId:"labels-user", displayName:"Labels fixture"}, provider:{idpId:"fixture", code:"NVIDIA"}}
        check(lockedFor("FREE"), "a Free account is not locked out of a paid game")
        check(!lockedFor("PERFORMANCE") && !lockedFor("ULTIMATE"), "a paid account is locked out")
        check(!lockedFor(null), "an unknown tier is locked out")
        check(!ShellStore.gameLockedByMembership(Object.assign({}, locked, {requiresPaidMembership:false})) ,
            "a game the catalog does not gate is locked")
        lockedFor("FREE")
        check(!ShellStore.gameLockedByMembership(crowded), "an ungated game is locked for a Free account")

        const owner = ShellStore.catalogOwnerState
        ShellStore.settings = Object.assign({}, ShellStore.settings, {onboardingCompleted:true})
        owner.catalogGames = [crowded, locked, plain]
        owner.catalogState = "ready"
        owner.catalogComplete = true
        return true
    }

    function verifyRendered(host) {
        const crowdedLabels = labelsFor(host, "labels-crowded")
        check(crowdedLabels, "crowded tile labels were not rendered")
        check(crowdedLabels.shownLaunchers === 3, "a tile shows more than three launchers")
        const overflow = child(crowdedLabels, "desktopGameLauncherOverflow")
        check(overflow && overflow.visible && overflow.text === "+2", "launcher overflow is not +2")
        const first = child(crowdedLabels, "desktopGameLauncher0")
        check(first && first.launcher.store === "GOG" && first.opacity === 1, "the owned launcher is not first and bright")
        check(child(first, "desktopGameOwnedDot").visible, "the owned launcher has no green dot")
        const second = child(crowdedLabels, "desktopGameLauncher1")
        check(second && second.opacity < 1 && !child(second, "desktopGameOwnedDot").visible, "an unowned launcher looks owned")
        check(!child(crowdedLabels, "desktopGameLock").visible, "an ungated game shows a lock")
        check(!child(crowdedLabels, "desktopGameFeature-dlss"), "an unsupported feature was drawn")
        const features = child(crowdedLabels, "desktopGameFeatures")
        const launcherPill = child(crowdedLabels, "desktopGameLaunchers")
        function separated() {
            return launcherPill.x + launcherPill.width < features.x && features.x + features.width <= crowdedLabels.width + 0.5
        }
        check(separated(), "the feature pill overlaps the launchers or overflows the tile")
        crowdedLabels.width = DesktopTokens.posterWidth - 16
        polish(crowdedLabels)
        check(crowdedLabels.shownLaunchers >= 1 && separated(), "the pills overlap on the narrowest Home tile")

        const lockedLabels = labelsFor(host, "labels-locked")
        check(lockedLabels && child(lockedLabels, "desktopGameLock").visible, "a paid game shows no lock for a Free account")
        check(lockedLabels.summary.indexOf("Needs a paid membership") === 0, "the lock is missing from the accessible description")
        ShellStore.subscription = {membershipTier:"ULTIMATE"}
        check(!child(lockedLabels, "desktopGameLock").visible, "the lock stayed after the tier changed")

        const plainLabels = collect(host, "desktopGameLabels", []).find(item => item.game && item.game.id === "labels-plain")
        check(plainLabels && !plainLabels.visible, "a game without catalog labels draws an empty pill")

        check(AppController.showOverlay("desktop-icon-guide"), "the icon guide overlay is not registered")
        const guide = collect(host, "desktopIconGuide", [])[0]
        check(guide && guide.opened, "the icon guide did not open")
        const listed = DesktopTokens.gameFeatureKeys.filter(key => child(guide, "desktopIconGuideFeature-" + key))
        check(JSON.stringify(listed) === JSON.stringify(["rtx", "hdr", "reflex"]) && !child(guide, "desktopIconGuideFeature-dlss"),
            "the icon guide lists features the catalog cannot back")
        const close = child(guide, "desktopIconGuideClose")
        guide.restoreFocus()
        check(close.activeFocus, "the icon guide did not take focus")
        check(guide.handleKey(Qt.Key_Tab) && close.activeFocus, "Tab left the icon guide")
        check(guide.handleKey(Qt.Key_Backtab) && close.activeFocus, "Shift+Tab left the icon guide")
        check(guide.handleKey(Qt.Key_Escape) && AppController.overlay === "", "Escape did not close the icon guide")
        check(!guide.opened, "the icon guide did not close")
        return true
    }
}
