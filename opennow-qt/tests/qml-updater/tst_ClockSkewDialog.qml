import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml/components"

Item {
    width: 900
    height: 600

    ClockSkewDialog {
        id: dialog
        anchors.centerIn: parent
        message: ""
        sessionSafe: true
        onDismissed: message = ""
    }

    TestCase {
        name: "ClockSkewDialog"
        when: windowShown

        function cleanup() {
            dialog.message = ""
            dialog.sessionSafe = true
            tryCompare(dialog, "visible", false)
        }

        function test_wrong_clock_is_announced_and_dismissible() {
            dialog.message = "Your computer's clock is about 7 hours ahead of GeForce NOW."
            tryCompare(dialog, "opened", true)
            compare(dialog.contentItem.textFormat, Text.PlainText)
            mouseClick(dialog.standardButton(Dialog.Ok))
            tryCompare(dialog, "visible", false)
            compare(dialog.message, "")
        }

        function test_stream_defers_the_notice() {
            dialog.sessionSafe = false
            dialog.message = "Your computer's clock is 12 minutes behind GeForce NOW."
            verify(!dialog.visible)
            dialog.sessionSafe = true
            tryCompare(dialog, "opened", true)
            keyClick(Qt.Key_Escape)
            tryCompare(dialog, "visible", false)
        }
    }
}
