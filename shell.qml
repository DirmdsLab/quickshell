
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import "module/launcher"
import "module/clipboard"
import "ipc"

ShellRoot {
    id: root

    property var activeLauncher: null

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData

            property bool focusGrabReady: false

            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            WlrLayershell.keyboardFocus:
                launcher.open || clipboard.open
                    ? WlrKeyboardFocus.Exclusive
                    : WlrKeyboardFocus.None

            Component.onCompleted: {
                if (root.activeLauncher === null)
                    root.activeLauncher = launcher
            }

            function syncOverlayFocus() {
                if (!launcher.open && !clipboard.open) {
                    focusGrabDelay.stop()
                    focusClearDelay.stop()
                    focusGrabReady = false
                    return
                }

                focusClearDelay.stop()

                focusGrabReady = false
                focusGrabDelay.restart()

                Qt.callLater(function() {
                    window.requestActivate()

                    if (clipboard.open)
                        clipboard.focusSearch()
                    else
                        launcher.focusSearch()
                })
            }

            Timer {
                id: focusGrabDelay

                interval: 180
                repeat: false

                onTriggered: {
                    if (launcher.open || clipboard.open)
                        window.focusGrabReady = true
                }
            }

            Timer {
                id: focusClearDelay

                interval: 120
                repeat: false

                onTriggered: {
                    if (launcher.open)
                        launcher.hide()

                    if (clipboard.open)
                        clipboard.hide()
                }
            }

            HyprlandFocusGrab {
                id: launcherFocusGrab

                windows: [window]

                active: (launcher.open || clipboard.open)
                    && window.focusGrabReady

                onCleared: {
                    if (window.focusGrabReady)
                        focusClearDelay.restart()
                }
            }

            LauncherIpc {
                launcher: launcher

                enabled: root.activeLauncher === launcher
            }

            ClipboardIpc {
                clipboard: clipboard

                enabled: root.activeLauncher === launcher
            }

            Connections {
                target: launcher

                function onOpenChanged() {
                    if (launcher.open && clipboard.open)
                        clipboard.hide()

                    window.syncOverlayFocus()
                }
            }

            Connections {
                target: clipboard

                function onOpenChanged() {
                    if (clipboard.open && launcher.open)
                        launcher.hide()

                    window.syncOverlayFocus()
                }
            }

            mask: Region {
                Region {
                    x: launcher.x
                    y: launcher.y
                    width: launcher.width
                    height: launcher.height
                }

                Region {
                    x: clipboard.x
                    y: clipboard.y
                    width: clipboard.width
                    height: clipboard.height
                }
            }

            Launcher {
                id: launcher
            }

            Clipboard {
                id: clipboard
            }
        }
    }
}
