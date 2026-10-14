import QtQuick
import QtQuick.Controls
import OpenNOW

AbstractButton {
    id: control
    property color fill: "#0FFFFFFF"
    property color hoverFill: "#1FFFFFFF"
    property color edge: "#17FFFFFF"
    property real radius: 12
    property string description: ""
    readonly property bool focusVisible: activeFocus && AppController.inputMode !== "pointer"
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    padding: 0
    opacity: enabled ? 1 : 0.45
    scale: pressed && !AppController.reducedMotion ? 0.985 : 1
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.description: description
    Behavior on scale { NumberAnimation { duration: DesktopTokens.quickDuration; easing.type: Easing.OutCubic } }

    onHoveredChanged: if (hovered && enabled && !activeFocus) forceActiveFocus()
    Keys.onReturnPressed: event => { control.clicked(); event.accepted = true }
    Keys.onEnterPressed: event => { control.clicked(); event.accepted = true }

    ToolTip.visible: description !== "" && hovered
    ToolTip.text: description
    ToolTip.delay: 700

    background: Rectangle {
        radius: control.radius
        color: control.down || control.hovered || control.focusVisible ? control.hoverFill : control.fill
        border.width: 1
        border.color: control.edge
        Behavior on color { ColorAnimation { duration: DesktopTokens.quickDuration } }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: DesktopTokens.focus
            visible: control.focusVisible
        }
    }
}
