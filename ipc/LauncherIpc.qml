pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var launcher

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (root.launcher)
                root.launcher.toggle()
        }

        function open(): void {
            if (root.launcher)
                root.launcher.show()
        }

        function close(): void {
            if (root.launcher)
                root.launcher.hide()
        }
    }
}