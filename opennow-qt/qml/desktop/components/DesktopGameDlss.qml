import QtQuick
import OpenNOW

// What a game's DLSS support (game.dlss, from NVIDIA's list) means on the
// account's plan. Entitlements come from subscription.dlssOverrides; the tier
// ladder is GeForce NOW help article 5876 and is kept only in `ladder`.
QtObject {
    id: root
    property var game: null
    readonly property var dlss: game && game.dlss ? game.dlss : null
    readonly property bool listed: dlss !== null
    readonly property bool notListed: Boolean(game) && "dlss" in game && game.dlss === null
    readonly property bool signedIn: ShellStore.signedIn
    readonly property bool planKnown: signedIn && ShellStore.dlssOverrideAvailability !== null

    readonly property var tiers: [{key: "FREE", label: qsTr("FREE"), name: qsTr("Free")},
        {key: "PERFORMANCE", label: qsTr("PERF"), name: qsTr("Performance")},
        {key: "ULTIMATE", label: qsTr("ULT"), name: qsTr("Ultimate")}]
    readonly property var ladder: ({superResolution: [true, true, true], frameGeneration: [false, true, true],
        rayReconstruction: [false, true, true], dlaa: [true, true, true]})
    readonly property int multiplierCap: 4

    readonly property int tierIndex: {
        const tier = planKnown && ShellStore.subscription ? String(ShellStore.subscription.membershipTier || "").toUpperCase() : ""
        return tiers.findIndex(item => item.key === tier)
    }
    readonly property string planName: tierIndex >= 0 ? tiers[tierIndex].name : qsTr("your plan")
    readonly property int listedMultiplier: listed && dlss.multiFrameGeneration
        ? Number(dlss.multiFrameGeneration.maxMultiplier) || 0 : 0
    readonly property int ultimateMultiplier: Math.min(multiplierCap, listedMultiplier)
    readonly property int multiplier: planKnown && ShellStore.dlssDynamicFrameGeneration && listedMultiplier > 0
        ? Math.min(ShellStore.dlssFrameGenerationMultipliers.reduce((high, value) => Math.max(high, Number(value)), 0),
            multiplierCap, listedMultiplier)
        : 0

    readonly property var rows: {
        if (!listed)
            return []
        const features = [
            {key: "superResolution", entitlement: "superResolution", name: qsTr("Super Resolution"), chip: qsTr("SR")},
            {key: "frameGeneration", entitlement: "frameGeneration", name: qsTr("Frame Generation"), chip: ""},
            {key: "rayReconstruction", entitlement: "rayReconstruction", name: qsTr("Ray Reconstruction"), chip: qsTr("RR")},
            {key: "dlaa", entitlement: "superResolution", name: qsTr("DLAA"), chip: qsTr("DLAA")}]
        return features.filter(feature => dlss[feature.key]).map(feature => {
            const capability = ShellStore.dlssCapability(feature.entitlement)
            const included = planKnown && capability.entitled === true
            const frameGeneration = feature.key === "frameGeneration"
            return Object.assign(feature, {
                status: !planKnown ? "neutral" : included ? "included" : "locked",
                upsell: planKnown && capability.upsell === true,
                chip: frameGeneration ? frameGenerationChip(included) : feature.chip,
                source: (dlss[feature.key] === "native" ? qsTr("IN GAME") : qsTr("OVERRIDE"))
                    + (frameGeneration && listedMultiplier > 0 ? " · " + listedMultiplier + "×" : ""),
                answer: answer(feature.key, included),
                tiers: tiers.map((tier, index) => index === tierIndex ? (included ? "included" : "missing")
                    : ladder[feature.key][index] ? "available" : "unavailable")
            })
        })
    }
    readonly property var strip: {
        if (!listed)
            return null
        if (!signedIn)
            return {kind: "signIn", glyph: "person", text: qsTr("Sign in to see your plan highlighted."), action: qsTr("Sign in")}
        const text = upsellText()
        return text ? {kind: "upsell", glyph: "crown", text: text, action: qsTr("See memberships")} : null
    }

    function frameGenerationChip(included) {
        if (!planKnown)
            return listedMultiplier > 0 ? qsTr("MFG %1× in list").arg(listedMultiplier) : qsTr("Frame Gen")
        if (!included)
            return qsTr("Frame Gen")
        return multiplier > 0 ? qsTr("MFG %1×").arg(multiplier) : qsTr("FG preset")
    }

    function answer(key, included) {
        const neutral = key === "rayReconstruction" ? qsTr("Performance and Ultimate")
            : key !== "frameGeneration" ? qsTr("Every plan")
            : listedMultiplier > 0 ? qsTr("Preset on Performance · MFG up to %1× on Ultimate").arg(ultimateMultiplier)
            : qsTr("Model preset on Performance and Ultimate")
        if (!planKnown)
            return neutral
        if (!included)
            return key === "frameGeneration" && listedMultiplier > 0
                ? qsTr("Not on %1 · Preset on Performance · %2× on Ultimate").arg(planName).arg(ultimateMultiplier)
                : qsTr("Not on %1 · %2").arg(planName).arg(neutral)
        if (key === "superResolution")
            return qsTr("Included · Upgrades the game's DLSS model")
        if (key === "rayReconstruction")
            return qsTr("Included · Replaces SR when RR is on in the game")
        if (key === "dlaa")
            return qsTr("Included · Native-resolution AA through the SR override")
        if (multiplier > 0)
            return multiplier < listedMultiplier
                ? qsTr("Up to %1× · Plus model preset · NVIDIA lists %2×, GeForce NOW caps at %1×").arg(multiplier).arg(listedMultiplier)
                : qsTr("Up to %1× · Plus model preset").arg(multiplier)
        return listedMultiplier > 0 ? qsTr("Model preset · No multiplier on your plan") : qsTr("Included · Model preset")
    }

    function upsellText() {
        const locked = rows.filter(row => row.status === "locked" && row.upsell).map(row => row.key)
        const frameGeneration = locked.indexOf("frameGeneration") >= 0
        const rayReconstruction = locked.indexOf("rayReconstruction") >= 0
        if (frameGeneration && rayReconstruction)
            return listedMultiplier > 0
                ? qsTr("Performance adds RR and the FG preset. Ultimate adds MFG up to %1×.").arg(ultimateMultiplier)
                : qsTr("Performance adds RR and the FG preset.")
        if (frameGeneration)
            return listedMultiplier > 0
                ? qsTr("Performance adds the FG preset. Ultimate adds MFG up to %1×.").arg(ultimateMultiplier)
                : qsTr("Performance adds the FG preset.")
        if (rayReconstruction)
            return qsTr("Performance adds Ray Reconstruction.")
        if (locked.length)
            return qsTr("A membership with these overrides adds %1.")
                .arg(rows.filter(row => locked.indexOf(row.key) >= 0).map(row => row.name).join(", "))
        const frames = rows.find(row => row.key === "frameGeneration")
        if (frames && frames.status === "included" && frames.upsell && multiplier === 0 && listedMultiplier > 0
                && tierIndex !== 2)
            return qsTr("Ultimate adds Multi Frame Generation up to %1× on RTX 5080 rigs.").arg(ultimateMultiplier)
        return ""
    }

    function activateStrip() {
        if (!strip)
            return
        if (strip.kind === "signIn")
            AppController.navigate("sign-in")
        else
            Qt.openUrlExternally("https://www.nvidia.com/geforce-now/memberships/")
    }
}
