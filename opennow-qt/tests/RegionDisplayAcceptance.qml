import QtQuick
import OpenNOW

QtObject {
    property Component chromeComponent: Component { AppChrome {} }
    property Component detailsComponent: Component { GameDetailScreen {} }

    function check(condition, message) {
        if (!condition) throw new Error("Region display acceptance: " + message)
    }

    function hasText(item, text) {
        if (item.text === text) return true
        for (const child of item.children || [])
            if (hasText(child, text)) return true
        return false
    }

    function run(host) {
        const originalSettings = ShellStore.settings
        const originalRegions = ShellStore.regions
        const originalPings = ShellStore.regionPingResults
        const chrome = chromeComponent.createObject(host, {visible: false, width: 1366, height: 768})
        const details = detailsComponent.createObject(host, {visible: false, width: 1366, height: 768})
        check(chrome && details, "console components were not created")
        const endpoint = "https://netherlands-north.example.invalid/streaming"
        const settings = Object.assign({}, originalSettings, {
            providerRegions: {"region-alliance": endpoint}
        })
        ShellStore.settings = settings
        ShellStore.regions = [{name: "Netherlands North", url: endpoint}]
        ShellStore.regionPingResults = ({[endpoint]: 0})
        check(chrome.regionName() === "Netherlands North", "chrome must resolve the selected endpoint")
        check(details.regionLabel() === "Netherlands North", "game details must resolve the selected endpoint")
        check(hasText(chrome, "Netherlands North · 0 ms"), "chrome must render the name and zero latency")
        check(hasText(details, "Netherlands North"), "game details must render the readable name")
        check(ShellStore.selectedRegion === endpoint, "display must not change the endpoint used at launch")

        ShellStore.regions = []
        check(chrome.regionName() === "Selected region" && details.regionLabel() === "Selected region",
              "pending discovery must not expose an endpoint")
        ShellStore.regions = [{name: "Netherlands North", url: endpoint}]
        check(hasText(chrome, "Netherlands North · 0 ms"), "discovery must update the rendered name")

        ShellStore.settings = Object.assign({}, settings, {providerRegions: {"region-alliance": "Netherlands North"}})
        check(chrome.regionName() === "Netherlands North" && details.regionLabel() === "Netherlands North",
              "legacy name selections must remain readable")
        ShellStore.settings = Object.assign({}, settings, {providerRegions: {"region-alliance": ""}})
        check(chrome.regionStatus() === "Automatic region" && details.regionLabel() === "Automatic region",
              "automatic selection must remain automatic")
        ShellStore.settings = Object.assign({}, settings, {providerRegions: {"other-provider": endpoint}})
        check(chrome.regionStatus() === "Automatic region", "another provider's selection must not leak")

        ShellStore.settings = originalSettings
        ShellStore.regions = originalRegions
        ShellStore.regionPingResults = originalPings
        chrome.destroy()
        details.destroy()
        return true
    }
}
