pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var quicksettings

    IpcHandler {
        target: "quicksettings"

        function toggle(): void {
            if (root.quicksettings)
                root.quicksettings.toggle()
        }

        function open(): void {
            if (root.quicksettings)
                root.quicksettings.show()
        }

        function close(): void {
            if (root.quicksettings)
                root.quicksettings.hide()
        }

        function focus(): void {
            if (root.quicksettings)
                root.quicksettings.focusPanel()
        }
    }
}
