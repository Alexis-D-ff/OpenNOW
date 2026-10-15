import QtQuick
import QtQuick.Window
import OpenNOW

QtObject {
    property OnboardingAcceptance acceptance: OnboardingAcceptance {}
    property var contentRoot: null
    property QtObject controller: QtObject {
        property int state: MacAwdlController.NotInstalled
        property bool busy: false
        property bool enabled: false
        property bool leased: false
        property string error: ""
        property int installRequests: 0
        property int uninstallRequests: 0
        property int refreshRequests: 0
        property int preferenceChanges: 0
        property int leaseChanges: 0
        onEnabledChanged: ++preferenceChanges
        onLeasedChanged: ++leaseChanges
        function refresh() { ++refreshRequests }
        function install() { ++installRequests }
        function uninstall() { ++uninstallRequests }
    }

    function run(parent) {
        contentRoot = parent
        acceptance.run(parent)
        const screen = acceptance.find(parent, "desktopOnboardingScreen")
        acceptance.check(screen, "AWDL fixture needs an onboarding screen")
        acceptance.check(screen.steps.indexOf("network") < 0, "unsupported AWDL showed network guidance")
        ShellStore.onboardingAwdlController = controller
        acceptance.check(String(screen.steps) === "mode,picture,network,boost,ready",
            "supported AWDL did not add network guidance between Picture and Boost")
        screen.goToStep(screen.steps.indexOf("network"))
        acceptance.check(acceptance.find(screen, "onboardingMacNetwork"), "AWDL guidance card is missing")
        if (Qt.application.arguments.indexOf("--onboarding-awdl-fullscreen") >= 0)
            parent.Window.window.showFullScreen()
        return true
    }

    function verify() {
        acceptance.verify()
        if (Qt.application.arguments.indexOf("--onboarding-awdl-fullscreen") >= 0)
            acceptance.check(contentRoot.Window.window.visibility === Window.FullScreen,
                "AWDL fullscreen fixture did not enter fullscreen")
        verifyRequirements()
        const screen = acceptance.find(contentRoot, "desktopOnboardingScreen")
        const card = acceptance.find(screen, "onboardingMacNetwork")
        acceptance.check(card && card.visible, "optional AWDL guidance is missing")
        const guidance = acceptance.find(card, "onboardingAwdlStatus")
        acceptance.check(guidance && guidance.visible && guidance.text.indexOf("Settings > Network") >= 0,
            "optional guidance does not point to desktop Network settings")
        acceptance.check(!acceptance.find(contentRoot, "onboardingAwdlChange")
            && !acceptance.find(contentRoot, "onboardingAwdlRefresh")
            && !acceptance.find(contentRoot, "onboardingAwdlConfirm"),
            "onboarding exposes helper actions instead of optional guidance")
        const scroll = acceptance.find(screen, "onboardingScroll")
        const point = card.mapToItem(scroll, 0, 0)
        acceptance.check(point.x >= -1 && point.x + card.width <= scroll.width + 1,
            "AWDL guidance is horizontally clipped")
        acceptance.check(controller.installRequests === 0 && controller.uninstallRequests === 0
            && controller.refreshRequests === 0, "onboarding called the optional helper controller")
        acceptance.check(!controller.enabled && !controller.leased
            && controller.preferenceChanges === 0 && controller.leaseChanges === 0,
            "onboarding changed the AWDL preference or streaming lease")
        return true
    }

    function verifyRequirements() {
        let screen = acceptance.find(contentRoot, "desktopOnboardingScreen")
        const owner = ShellStore.onboardingOwnerState
        const initialRequests = acceptance.client.requests.length
        for (const status of [MacAwdlController.NotInstalled, MacAwdlController.Installed, MacAwdlController.Unsupported]) {
            for (const busy of [false, true]) {
                controller.state = status
                controller.busy = busy
                controller.error = "Optional helper authorization failed"
                acceptance.check(ShellStore.verifyOnboardingRequirements() && ShellStore.onboardingAwdlReady,
                    "optional helper state blocked setup: " + status + ", busy: " + busy)
                if (status === MacAwdlController.Unsupported) {
                    acceptance.check(screen.steps.indexOf("network") < 0
                        && !acceptance.find(screen, "onboardingMacNetwork"),
                        "AWDL guidance is visible on an unsupported platform")
                    continue
                }
                screen.goToStep(screen.steps.indexOf("network"))
                acceptance.check(acceptance.find(screen, "onboardingNext").enabled,
                    "optional network page disabled Continue")
                screen.next()
                acceptance.check(screen.step === "boost", "optional network page blocked Continue")
            }
        }
        acceptance.check(acceptance.client.requests.length === initialRequests,
            "checking optional network guidance wrote settings")
        controller.state = MacAwdlController.NotInstalled
        controller.busy = true
        owner.setSetting("fps", 120)
        screen.goToStep(screen.steps.indexOf("ready"))
        screen.next()
        acceptance.check(owner.saving, "pending optional helper blocked settings persistence")
        controller.state = MacAwdlController.Installed
        acceptance.acknowledge()
        acceptance.check(owner.saving && acceptance.client.requests[acceptance.client.requests.length - 1].params.key === "onboardingCompleted",
            "helper state change during saving blocked the completion-marker write")
        acceptance.acknowledge()
        acceptance.check(!owner.saving && !owner.needed && ShellStore.settings.fps === 120,
            "Finish did not persist choices with an optional helper")
        ShellStore.settings = Object.assign({}, ShellStore.settings, {onboardingCompleted: false})
        screen = acceptance.find(contentRoot, "desktopOnboardingScreen")
        controller.state = MacAwdlController.NotInstalled
        screen.skip()
        acceptance.check(owner.saving && acceptance.client.requests[acceptance.client.requests.length - 1].params.key === "onboardingCompleted",
            "Skip did not persist completion without a helper")
        acceptance.acknowledge()
        acceptance.check(!owner.saving && !owner.needed, "Skip did not complete without a helper")
        ShellStore.settings = Object.assign({}, ShellStore.settings, {onboardingCompleted: false})
        screen = acceptance.find(contentRoot, "desktopOnboardingScreen")
        controller.busy = false
        controller.error = ""
        screen.goToStep(screen.steps.indexOf("network"))
    }
}
