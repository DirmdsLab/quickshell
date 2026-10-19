import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import "module/launcher"
import "module/clipboard"
import "module/settings"
import "module/quicksettings"
import "ipc"

ShellRoot {
    id: root

    property var activeLauncher: null
    property var activeQuickSettings: null

    QuickSettingsIpc {
        quicksettings: root.activeQuickSettings
    }

    Settings {
        id: settings
    }

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
            focusable: launcher.open || clipboard.open || quicksettings.open

            WlrLayershell.keyboardFocus:
                launcher.open || clipboard.open || quicksettings.open
                    ? WlrKeyboardFocus.Exclusive
                    : WlrKeyboardFocus.None

            Component.onCompleted: {
                if (root.activeLauncher === null)
                    root.activeLauncher = launcher

                if (root.activeQuickSettings === null)
                    root.activeQuickSettings = quicksettings
            }

            function syncOverlayFocus() {
                focusClearDelay.stop()

                if (!launcher.open && !clipboard.open && !quicksettings.open) {
                    focusGrabDelay.stop()
                    focusGrabReady = false
                    return
                }

                focusGrabReady = false
                focusGrabDelay.restart()

                Qt.callLater(function() {
                    if (!launcher.open && !clipboard.open && !quicksettings.open)
                        return

                    window.requestActivate()

                    if (clipboard.open)
                        clipboard.focusSearch()
                    else if (launcher.open)
                        launcher.focusSearch()
                    else
                        quicksettings.focusPanel()
                })
            }

            Timer {
                id: focusGrabDelay
                interval: 180
                repeat: false

                onTriggered: {
                    if (launcher.open || clipboard.open || quicksettings.open)
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

                    if (quicksettings.open)
                        quicksettings.hide()

                    window.focusGrabReady = false
                }
            }

            HyprlandFocusGrab {
                id: overlayFocusGrab
                windows: [window]

                active: (launcher.open || clipboard.open || quicksettings.open)
                    && window.focusGrabReady

                onCleared: {
                    if (!window.focusGrabReady)
                        return

                    window.focusGrabReady = false
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

                function onSettingsRequested() {
                    if (launcher.open)
                        launcher.hide()

                    if (clipboard.open)
                        clipboard.hide()

                    if (quicksettings.open)
                        quicksettings.hide()

                    if (settings.windowShown) {
                        settings.hideImmediately()
                        Qt.callLater(function() {
                            settings.show()
                        })
                    } else {
                        settings.show()
                    }
                }

                function onOpenChanged() {
                    if (launcher.open) {
                        if (clipboard.open)
                            clipboard.hide()

                        if (quicksettings.open)
                            quicksettings.hide()
                    }

                    window.syncOverlayFocus()
                }
            }

            Connections {
                target: clipboard

                function onOpenChanged() {
                    if (clipboard.open) {
                        if (launcher.open)
                            launcher.hide()

                        if (quicksettings.open)
                            quicksettings.hide()
                    }

                    window.syncOverlayFocus()
                }
            }

            Connections {
                target: quicksettings

                function onOpenChanged() {
                    if (quicksettings.open) {
                        if (launcher.open)
                            launcher.hide()

                        if (clipboard.open)
                            clipboard.hide()
                    }

                    window.syncOverlayFocus()
                }
            }

            Connections {
                target: settings

                function onOpenChanged() {
                    if (settings.open) {
                        if (launcher.open)
                            launcher.hide()

                        if (clipboard.open)
                            clipboard.hide()

                        if (quicksettings.open)
                            quicksettings.hide()
                    }
                }
            }

            mask: Region {
                Region {
                    x: launcher.x
                    y: launcher.y
                    width: launcher.open ? launcher.width : 0
                    height: launcher.open ? launcher.height : 0
                }

                Region {
                    x: clipboard.x
                    y: clipboard.y
                    width: clipboard.open ? clipboard.width : 0
                    height: clipboard.open ? clipboard.height : 0
                }

                Region {
                    x: quicksettings.x
                    y: quicksettings.y
                    width: quicksettings.visible ? quicksettings.width : 0
                    height: quicksettings.visible ? quicksettings.height : 0
                }
            }

            Launcher {
                id: launcher
            }

            Clipboard {
                id: clipboard
            }

            QuickSettings {
                id: quicksettings
            }
        }
    }
}
