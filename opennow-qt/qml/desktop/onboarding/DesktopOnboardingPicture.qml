pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import OpenNOW

Column {
    id: root
    required property var store
    readonly property var settings: store.onboardingSettings
    readonly property string resolution: String(settings.resolution || "1920x1080")
    property bool fineTuneOpen: false
    readonly property color mint: Theme.accentColor("green")
    readonly property color panelColor: Theme.lightMode ? Theme.glass : "#C70B0F1A"
    spacing: DesktopTokens.px(24)

    component Copy: Text {
        color: Theme.textMuted
        font.family: Theme.bodyFont
        font.pixelSize: DesktopTokens.px(12)
        wrapMode: Text.WordWrap
        lineHeightMode: Text.FixedHeight
        lineHeight: DesktopTokens.px(font.pixelSize >= DesktopTokens.px(14) ? 18 : 16)
    }
    component SettingRow: Item {
        id: settingRow
        property string title
        property string description
        property string glyph
        property bool divider: true
        default property alias control: controlSlot.data
        readonly property bool stacked: width < DesktopTokens.px(600)
        implicitHeight: Math.max(DesktopTokens.px(67), labels.implicitHeight + DesktopTokens.px(28))
            + (stacked ? controlSlot.implicitHeight + DesktopTokens.px(12) : 0)
        Rectangle {
            x: DesktopTokens.px(18)
            y: DesktopTokens.px(16)
            width: DesktopTokens.px(36); height: width
            radius: DesktopTokens.px(10); color: DesktopTokens.raised
            DesktopSettingsIcon { anchors.centerIn: parent; width: DesktopTokens.px(16); height: width; glyph: settingRow.glyph; ink: Theme.label }
        }
        Column {
            id: labels
            x: DesktopTokens.px(68)
            y: settingRow.stacked ? DesktopTokens.px(14) : (parent.height - height) / 2
            width: parent.width - x - DesktopTokens.px(18) - (settingRow.stacked ? 0 : controlSlot.width + DesktopTokens.px(14))
            spacing: DesktopTokens.px(3)
            Copy { width: parent.width; text: settingRow.title; color: Theme.label; font.pixelSize: DesktopTokens.px(14); font.weight: Font.ExtraBold }
            Copy { width: parent.width; text: settingRow.description }
        }
        Row {
            id: controlSlot
            anchors.right: parent.right; anchors.rightMargin: DesktopTokens.px(18)
            y: settingRow.stacked ? labels.y + labels.height + DesktopTokens.px(12) : (parent.height - height) / 2
            spacing: DesktopTokens.px(8)
        }
        Rectangle { visible: settingRow.divider; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: DesktopTokens.seamSoft }
    }
    component Segments: Item {
        id: segments
        property var options: []
        property int selectedIndex: 0
        property int optionWidth: 56
        property var disabledValues: []
        property string disabledHint: ""
        signal selected(int index, var value)
        function optionValue(option) { return typeof option === "object" ? option.value : option }
        function isDisabled(option) { return option.enabled === false || disabledValues.some(value => String(optionValue(value)) === String(optionValue(option))) }
        implicitWidth: DesktopTokens.px(6) + options.length * DesktopTokens.px(optionWidth + 2)
        implicitHeight: DesktopTokens.px(36)
        Rectangle { anchors.fill: parent; radius: height / 2; color: DesktopTokens.raised; border.color: DesktopTokens.seamSoft }
        Row {
            x: DesktopTokens.px(3); y: DesktopTokens.px(3); spacing: DesktopTokens.px(2)
            Repeater {
                model: segments.options
                AbstractButton {
                    id: segment
                    required property int index
                    required property var modelData
                    objectName: "settingsOption-" + String(segments.optionValue(modelData))
                    width: DesktopTokens.px(segments.optionWidth); height: DesktopTokens.px(30)
                    enabled: !segments.isDisabled(modelData); opacity: enabled ? 1 : 0.45
                    checkable: true; checked: index === segments.selectedIndex
                    Accessible.name: label.text
                    onClicked: segments.selected(index, modelData)
                    background: Rectangle { radius: height / 2; color: segment.checked ? Theme.face : segment.hovered ? DesktopTokens.raised : "transparent"; border.width: segment.activeFocus ? 2 : 0; border.color: Theme.focus }
                    contentItem: Text {
                        id: label
                        text: typeof segment.modelData === "object" ? segment.modelData.label : String(segment.modelData)
                        color: segment.checked ? Theme.faceText : Theme.textMuted
                        font.family: Theme.bodyFont; font.pixelSize: DesktopTokens.px(13); font.weight: Font.ExtraBold
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    ToolTip.visible: hovered && !enabled && segments.disabledHint !== ""
                    ToolTip.text: segments.disabledHint
                }
            }
        }
    }
    component BitrateSlider: Row {
        id: control
        property alias from: slider.from
        property alias to: slider.to
        property alias stepSize: slider.stepSize
        property alias value: slider.value
        property real trackWidth: DesktopTokens.px(220)
        property string suffix: ""
        property string accessibleName: ""
        signal moved(real value)
        spacing: DesktopTokens.px(16)
        Slider {
            id: slider
            width: control.trackWidth; height: DesktopTokens.px(28)
            leftPadding: 0; rightPadding: 0
            Accessible.name: control.accessibleName
            onMoved: control.moved(value)
            background: Rectangle {
                anchors.verticalCenter: parent.verticalCenter; width: parent.width
                height: DesktopTokens.px(4); radius: height / 2; color: DesktopTokens.raisedStrong
                Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: height / 2; color: root.mint }
            }
            handle: Rectangle {
                x: slider.visualPosition * (slider.width - width); anchors.verticalCenter: parent.verticalCenter
                width: DesktopTokens.px(18); height: width; radius: width / 2; color: Theme.label
                border.width: slider.activeFocus ? 2 : 0; border.color: root.mint
            }
        }
        Text {
            width: DesktopTokens.px(72); height: DesktopTokens.px(28)
            text: (Math.round(slider.value * 100) / 100) + control.suffix
            color: Theme.label; font.family: Theme.monoFont; font.pixelSize: DesktopTokens.px(14); font.weight: Font.Bold
            verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight
        }
    }

    Rectangle {
        objectName: "onboardingPicturePanel"
        width: Math.min(parent.width, DesktopTokens.px(860))
        anchors.horizontalCenter: parent.horizontalCenter
        implicitHeight: rows.implicitHeight
        radius: DesktopTokens.px(16); color: root.panelColor; border.color: Theme.seam
        Column {
            id: rows
            width: parent.width
            DesktopSettingsResolution {
                objectName: "onboardingResolution"
                width: parent.width
                items: root.store.resolutionItems()
                value: root.resolution
                onSelected: value => root.store.setOnboardingSetting("resolution", value)
            }
            SettingRow {
                width: parent.width; title: qsTr("Frame rate"); glyph: "speed"
                description: qsTr("Rates follow your membership and resolution.")
                Segments {
                    objectName: "onboardingFps"
                    readonly property var canonical: root.store.canonicalFpsValues()
                    readonly property int current: Number(root.settings.fps ?? 60)
                    options: canonical.indexOf(current) >= 0 ? canonical
                        : [{label: current === 0 ? qsTr("Auto") : String(current), value: current}].concat(canonical)
                    optionWidth: 46
                    selectedIndex: options.findIndex(item => Number(optionValue(item)) === current)
                    disabledValues: root.store.lockedFpsValues(root.resolution)
                    disabledHint: root.store.unentitledFpsValues(root.resolution).length
                        ? qsTr("Not available on your current membership")
                        : root.store.lockedFpsReason()
                            || qsTr("Not available on your current membership")
                    onSelected: (index, item) => root.store.setOnboardingSetting("fps", Number(optionValue(item)))
                }
            }
            DesktopSettingsRow {
                objectName: "onboardingFineTune"
                width: parent.width; paperStyle: true; glyph: "sliders"
                title: qsTr("Fine-tune")
                description: qsTr("%1 · Codec %2 · %3 Mbps maximum")
                    .arg(root.settings.enableHdr === true ? qsTr("HDR on") : qsTr("HDR off"))
                    .arg(String(root.settings.codec || "auto") === "auto" ? qsTr("Auto") : String(root.settings.codec).toUpperCase())
                    .arg(root.settings.maxBitrateMbps ?? 75)
                expandable: true; expanded: root.fineTuneOpen
                showDivider: root.fineTuneOpen
                onExpansionRequested: root.fineTuneOpen = !root.fineTuneOpen
            }
            DesktopSettingsDisclosure {
                objectName: "onboardingFineTuneDisclosure"
                width: parent.width
                expanded: root.fineTuneOpen
                sourceComponent: Column {
                    SettingRow {
                        id: hdrRow
                        readonly property string status: !root.store.tenBitAllowedByMembership() ? qsTr("HDR10 requires a Performance or Ultimate membership.")
                            : HdrOutput.supported && !root.store.hdrDecoderAvailable()
                            ? qsTr("HDR requires a supported 10-bit H.265 or AV1 hardware decoder.") : HdrOutput.status
                        width: parent.width; title: qsTr("HDR"); glyph: "sun"
                        description: !HdrOutput.supported ? qsTr("HDR is unavailable on this display.") : status
                        HoverHandler { id: hdrHover; parent: hdrRow }
                        ToolTip.visible: hdrHover.hovered
                        ToolTip.text: status
                        ToolTip.delay: 500
                        DesktopSettingsToggle {
                            objectName: "onboardingHdr"
                            checked: root.settings.enableHdr === true
                            enabled: ((HdrOutput.supported && root.store.hdrDecoderAvailable()) || checked) && (root.store.tenBitAllowedByMembership() || checked)
                            opacity: enabled ? 1 : 0.45
                            Accessible.name: qsTr("HDR")
                            Accessible.description: hdrRow.status
                            onValueChangedByUser: value => root.store.setOnboardingSetting("enableHdr", value)
                        }
                    }
                    SettingRow {
                        width: parent.width; title: qsTr("Codec"); glyph: "chip"
                        description: qsTr("Auto chooses a supported native decoder.")
                        Segments {
                            objectName: "onboardingCodec"
                            options: [{label:qsTr("Auto"),value:"auto"},
                                {label:"AV1",value:"av1",enabled:root.store.codecAvailable("av1") && !root.store.codecDisabledByProfile("av1")},
                                {label:"H.265",value:"h265",enabled:root.store.codecAvailable("h265") && !root.store.codecDisabledByProfile("h265")},
                                {label:"H.264",value:"h264",enabled:root.store.codecAvailable("h264") && !root.store.codecDisabledByProfile("h264")}]
                            optionWidth: 59
                            selectedIndex: options.findIndex(item => item.value === String(root.settings.codec || "auto"))
                            disabledHint: qsTr("Not supported by the detected decoder or the selected color quality")
                            onSelected: (index, item) => root.store.setOnboardingSetting("codec", item.value)
                        }
                    }
                    SettingRow {
                        id: bitrateRow
                        width: parent.width; title: qsTr("Bitrate"); glyph: "wave"; divider: false
                        description: qsTr("Higher values use more bandwidth. Requested maximum, not a network test.")
                        BitrateSlider {
                            objectName: "onboardingBitrate"; accessibleName: qsTr("Bitrate")
                            trackWidth: Math.min(DesktopTokens.px(220), Math.max(DesktopTokens.px(100), bitrateRow.width - DesktopTokens.px(470)))
                            from: 0.22; to: 200; stepSize: 0.01; suffix: qsTr(" Mbps")
                            value: Number(root.settings.maxBitrateMbps ?? 75)
                            onMoved: value => root.store.setOnboardingSetting("maxBitrateMbps", Math.round(value * 100) / 100)
                        }
                    }
                }
            }
        }
    }
}
