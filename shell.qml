import QtQuick
import Quickshell
import Quickshell.Wayland

import "module/launcher"
import "ipc"

ShellRoot {
    id: root

    property var activeLauncher: null

    LauncherIpc {
        launcher: root.activeLauncher
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData

            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            Component.onCompleted: {
                if (root.activeLauncher === null)
                    root.activeLauncher = launcher
            }

            Region {
                id: inputRegion

                Region {
                    x: launcher.x
                    y: launcher.y
                    width: launcher.width
                    height: launcher.height
                }
            }

            mask: inputRegion

            Launcher {
                id: launcher
            }
        }
    }
}