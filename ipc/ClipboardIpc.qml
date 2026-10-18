
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var clipboard

    IpcHandler {
        target: "clipboard"

        enabled: root.enabled

        function toggle(): void {
            if (root.clipboard)
                root.clipboard.toggle()
        }

        function open(): void {
            if (root.clipboard)
                root.clipboard.show()
        }

        function close(): void {
            if (root.clipboard)
                root.clipboard.hide()
        }

        function focus(): void {
            if (root.clipboard)
                root.clipboard.focusSearch()
        }
    }
}
