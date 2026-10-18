
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var launcher

    IpcHandler {
        target: "launcher"
        enabled: root.enabled

        function toggle(): void {
            console.info("[LauncherIpc] Toggle requested")

            if (!root.launcher) {
                console.warn("[LauncherIpc] Launcher is unavailable")
                return
            }

            root.launcher.toggle()
        }

        function open(): void {
            console.info("[LauncherIpc] Open requested")

            if (root.launcher)
                root.launcher.show()
        }

        function close(): void {
            console.info("[LauncherIpc] Close requested")

            if (root.launcher)
                root.launcher.hide()
        }

        function focus(): void {
            console.info("[LauncherIpc] Focus requested")

            if (root.launcher)
                root.launcher.focusSearch()
        }
    }
}
