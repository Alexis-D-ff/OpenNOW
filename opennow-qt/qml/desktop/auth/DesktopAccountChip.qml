import QtQuick
import OpenNOW

// Tier or alliance chip for a saved account. Tier values come from the core
// (FREE, PERFORMANCE, ULTIMATE); anything else renders neutrally as-is.
Rectangle {
    id: root
    property string tier: ""
    property string partnerName: ""
    property real unit: 1
    property bool compactTier: false
    readonly property bool alliance: partnerName !== ""
    readonly property string tierKey: String(tier || "").trim().toUpperCase()
    readonly property color accent: alliance ? "#A78BFA"
        : tierKey === "ULTIMATE" ? DesktopTokens.amber
        : tierKey === "PERFORMANCE" || tierKey === "PRIORITY" ? "#7FD4FF" : (Theme.lightMode ? "#0B0F1A" : "#FFFFFF")
    readonly property bool neutral: !alliance && ["ULTIMATE", "PERFORMANCE", "PRIORITY"].indexOf(tierKey) < 0
    readonly property color ink: alliance ? (Theme.lightMode ? "#5B3FC4" : "#D9CCFF")
        : neutral ? Qt.rgba(accent.r, accent.g, accent.b, 0.78)
        : Theme.lightMode ? Qt.darker(accent, 2.1) : accent
    readonly property string label: alliance
        ? qsTr("%1 · ALLIANCE").arg(partnerName.toUpperCase())
        : (compactTier && tierKey === "PERFORMANCE" ? qsTr("PERF.") : tierKey)

    function u(value) { return Math.max(1, Math.round(value * root.unit)) }

    visible: label !== ""
    implicitWidth: row.implicitWidth + (alliance ? u(4) + u(8) : u(16))
    implicitHeight: u(23)
    width: implicitWidth
    height: implicitHeight
    radius: u(6)
    color: Qt.rgba(accent.r, accent.g, accent.b, neutral ? 0.07 : 0.12)
    border.width: 1
    border.color: Qt.rgba(accent.r, accent.g, accent.b, neutral ? 0.2 : 0.37)
    Accessible.role: Accessible.StaticText
    Accessible.name: alliance ? qsTr("Plays through %1, an alliance partner").arg(partnerName) : label

    Row {
        id: row
        x: root.alliance ? root.u(4) : root.u(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.u(6)
        Rectangle {
            visible: root.alliance
            anchors.verticalCenter: parent.verticalCenter
            width: root.u(16)
            height: width
            radius: root.u(4)
            color: "#A78BFA"
            Text {
                anchors.centerIn: parent
                text: root.partnerName.charAt(0).toUpperCase()
                color: "#0B0F1A"
                font.family: DesktopTokens.displayFont
                font.pixelSize: root.u(10)
                font.weight: Font.Black
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.u(220))
            text: root.label
            elide: Text.ElideRight
            color: root.ink
            font.family: DesktopTokens.monoFont
            font.pixelSize: root.u(11)
            font.weight: Font.DemiBold
            font.letterSpacing: root.alliance ? root.u(11) * 0.04 : root.u(11) * 0.08
        }
    }
}
