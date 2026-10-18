import QtQuick
import QtQuick.Controls
import Quickshell

FloatingWindow {
    id: root

    title: "UwU Settings"
    width: 960
    height: 540
    minimumSize: Qt.size(720, 405)
    color: "transparent"

    property bool open: false
    property bool closing: false
    property real progress: open ? 1 : 0
    property int selectedIndex: 0
    property string query: ""

    property var sections: [
        { name: "Network & internet", description: "Wi-Fi, Ethernet, hotspot and VPN", icon: "◉", items: [
            { title: "Internet", description: "Wi-Fi, mobile network and Ethernet", status: "Disconnected", icon: "◉" },
            { title: "Hotspot & tethering", description: "Share your connection with other devices", status: "Off", icon: "⌁" },
            { title: "VPN", description: "Manage virtual private network connections", status: "None", icon: "◇" }
        ]},
        { name: "Connected devices", description: "Bluetooth, pairing and sharing", icon: "▣", items: [
            { title: "Bluetooth", description: "Pair and manage nearby devices", status: "Off", icon: "ᛒ" },
            { title: "Pair new device", description: "Connect a new accessory", status: "", icon: "+" },
            { title: "Nearby Share", description: "Share files with nearby devices", status: "Off", icon: "↗" }
        ]},
        { name: "Apps", description: "Installed apps and defaults", icon: "▦", items: [
            { title: "All apps", description: "Manage installed applications", status: "", icon: "▦" },
            { title: "Default apps", description: "Choose apps for links and file types", status: "", icon: "◇" },
            { title: "App permissions", description: "Control access to system resources", status: "", icon: "▤" }
        ]},
        { name: "Notifications", description: "App alerts and notification history", icon: "♧", items: [
            { title: "App notifications", description: "Choose which apps can notify you", status: "", icon: "♧" },
            { title: "Do Not Disturb", description: "Silence interruptions", status: "Off", icon: "◐" },
            { title: "Notification history", description: "Review dismissed notifications", status: "Off", icon: "◷" }
        ]},
        { name: "Battery", description: "Power usage and battery health", icon: "▰", items: [
            { title: "Battery usage", description: "See which apps use the most power", status: "", icon: "▰" },
            { title: "Battery Saver", description: "Extend battery life", status: "Off", icon: "ϟ" },
            { title: "Charging", description: "Charging status and battery details", status: "75%", icon: "⌁" }
        ]},
        { name: "Storage", description: "Space used by files and applications", icon: "▤", items: [
            { title: "Internal storage", description: "Review storage usage", status: "92% used", icon: "▤" },
            { title: "Temporary files", description: "Cached data and temporary files", status: "", icon: "⌫" },
            { title: "Storage manager", description: "Automatically free up space", status: "Off", icon: "◷" }
        ]},
        { name: "Sound & vibration", description: "Volume, sounds and haptics", icon: "◖", items: [
            { title: "Volume", description: "Media, call, ring and alarm volume", status: "", icon: "◖" },
            { title: "Notification sound", description: "Choose a notification sound", status: "", icon: "♫" },
            { title: "Vibration & haptics", description: "Touch feedback and vibration strength", status: "", icon: "〰" }
        ]},
        { name: "Display", description: "Brightness, theme and screen timeout", icon: "◐", items: [
            { title: "Brightness", description: "Adjust display brightness", status: "", icon: "☼" },
            { title: "Dark theme", description: "Use a dark color scheme", status: "On", icon: "◐" },
            { title: "Screen timeout", description: "Choose when the screen turns off", status: "5 minutes", icon: "◷" }
        ]},
        { name: "Wallpaper & style", description: "Personalize colors and appearance", icon: "▧", items: [
            { title: "Wallpaper", description: "Choose a desktop background", status: "", icon: "▧" },
            { title: "Color palette", description: "Choose accent colors", status: "", icon: "◈" },
            { title: "Interface style", description: "Adjust shapes and layout", status: "", icon: "▦" }
        ]},
        { name: "Privacy & security", description: "Permissions and device protection", icon: "◇", items: [
            { title: "Permission manager", description: "Review application permissions", status: "", icon: "◇" },
            { title: "Screen lock", description: "Configure screen lock behavior", status: "", icon: "▣" },
            { title: "Device security", description: "Review security status", status: "Protected", icon: "✓" }
        ]},
        { name: "System", description: "Languages, gestures and updates", icon: "⚙", items: [
            { title: "Languages", description: "Choose display and input languages", status: "", icon: "文" },
            { title: "Date & time", description: "Time zone and clock settings", status: "", icon: "◷" },
            { title: "System update", description: "Check for system updates", status: "Up to date", icon: "↻" }
        ]},
        { name: "About", description: "Version and system information", icon: "ⓘ", items: [
            { title: "Device information", description: "System and hardware details", status: "", icon: "ⓘ" },
            { title: "Version", description: "Installed operating system version", status: "Preview", icon: "▤" },
            { title: "Build number", description: "Build and release information", status: "Dummy", icon: "#" }
        ]}
    ]

    property var currentSection: sections[Math.max(0, Math.min(selectedIndex, sections.length - 1))]

    function show() {
        closeTimer.stop()
        closing = false
        open = true
        Qt.callLater(function() {
            if (root.open)
                searchField.forceActiveFocus()
        })
    }

    function hide() {
        if (!open && !closing)
            return

        open = false
        closing = true
        searchField.focus = false
        closeTimer.restart()
    }

    function toggle() {
        if (open) hide()
        else show()
    }

    function focusSearch() {
        if (open) searchField.forceActiveFocus()
    }

    function matchesSection(section) {
        const value = query.trim().toLowerCase()
        return value.length === 0
            || section.name.toLowerCase().includes(value)
            || section.description.toLowerCase().includes(value)
    }

    visible: open || closing

    onClosing: function(closeEvent) {
        closeEvent.accepted = false
        root.hide()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.hide()
    }

    Timer {
        id: closeTimer
        interval: 240
        repeat: false

        onTriggered: {
            if (!root.open)
                root.closing = false
        }
    }

    Behavior on progress {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 26
        color: "#171d1d"
        border.width: 1
        border.color: "#384141"
        opacity: root.progress
        scale: 0.97 + root.progress * 0.03
        clip: true

        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: sidebar
                width: panel.width * 0.32
                height: parent.height
                color: "#111717"
                radius: 26

                Rectangle {
                    x: sidebar.width - 26
                    y: 0
                    width: 26
                    height: sidebar.height
                    color: sidebar.color
                }

                Text {
                    x: 25; y: 22
                    text: "Settings"
                    color: "#e6eeee"
                    font.pixelSize: 25
                    font.weight: Font.DemiBold
                }
                Text {
                    x: 27; y: 54
                    text: "System preferences"
                    color: "#9baaaa"
                    font.pixelSize: 12
                }

                TextField {
                    id: searchField
                    x: 18; y: 83
                    width: sidebar.width - 36
                    height: 42
                    placeholderText: "Search settings"
                    text: root.query
                    color: "#e6eeee"
                    placeholderTextColor: "#879595"
                    font.pixelSize: 13
                    selectByMouse: true
                    background: Rectangle {
                        radius: 14
                        color: "#252d2d"
                        border.width: searchField.activeFocus ? 1 : 0
                        border.color: "#9eeaf3"
                    }
                    onTextChanged: root.query = text
                    Keys.onEscapePressed: root.hide()
                }

                ListView {
                    id: navigationList
                    x: 12; y: 138
                    width: sidebar.width - 24
                    height: sidebar.height - 150
                    clip: true
                    spacing: 4
                    model: root.sections
                    currentIndex: root.selectedIndex

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: navigationList.width
                        height: root.matchesSection(modelData) ? 46 : 0
                        visible: height > 0
                        radius: 14
                        color: index === root.selectedIndex ? "#34484a"
                            : navMouse.containsMouse ? "#222b2b" : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            text: modelData.icon
                            color: index === root.selectedIndex ? "#a3edf5" : "#bdc9c9"
                            font.pixelSize: 17
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 43
                            anchors.right: parent.right
                            anchors.rightMargin: 7
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: index === root.selectedIndex ? "#effafa" : "#c5d0d0"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.selectedIndex = index
                                navigationList.currentIndex = index
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: mainPane
                width: panel.width - sidebar.width
                height: parent.height
                color: "#1b2222"
                radius: 26

                Rectangle {
                    x: 0
                    y: 0
                    width: 26
                    height: mainPane.height
                    color: mainPane.color
                }

                Text {
                    x: 30; y: 26
                    width: mainPane.width - 60
                    text: root.currentSection.name
                    color: "#edf4f4"
                    font.pixelSize: 27
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    x: 32; y: 65
                    width: mainPane.width - 64
                    text: root.currentSection.description
                    color: "#aab8b8"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Rectangle {
                    x: 30; y: 100
                    width: mainPane.width - 60
                    height: 1
                    color: "#303a3a"
                }

                ListView {
                    id: settingsList
                    x: 22; y: 114
                    width: mainPane.width - 44
                    height: mainPane.height - 132
                    clip: true
                    spacing: 7
                    model: root.currentSection.items

                    delegate: Rectangle {
                        required property var modelData
                        width: settingsList.width
                        height: 68
                        radius: 14
                        color: rowMouse.containsMouse ? "#283232" : "#202828"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            x: 12; width: 38; height: 38
                            radius: 19
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#303f40"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: "#b0eaf0"
                                font.pixelSize: 17
                            }
                        }
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 62
                            anchors.right: statusLabel.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                width: parent.width
                                text: modelData.title
                                color: "#e5eeee"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: modelData.description
                                color: "#9faaaa"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            id: statusLabel
                            anchors.right: parent.right
                            anchors.rightMargin: 27
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.status || ""
                            color: "#aab8b8"
                            font.pixelSize: 11
                            visible: text.length > 0
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: "#879999"
                            font.pixelSize: 22
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: console.log("Dummy setting selected:", modelData.title)
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 9
                    text: "Settings preview"
                    color: "#627171"
                    font.pixelSize: 10
                }
            }
        }
    }

    MouseArea {
        id: dragArea
        x: 0
        y: 0
        width: root.width
        height: 72
        z: 10
        acceptedButtons: Qt.LeftButton
        onPressed: root.startSystemMove()
    }

    MouseArea {
        x: 0
        y: 0
        width: 12
        height: root.height
        z: 20
        cursorShape: Qt.SizeHorCursor
        acceptedButtons: Qt.LeftButton
        onPressed: root.startSystemResize(Qt.LeftEdge)
    }

    MouseArea {
        x: root.width - 12
        y: 0
        width: 12
        height: root.height
        z: 20
        cursorShape: Qt.SizeHorCursor
        acceptedButtons: Qt.LeftButton
        onPressed: root.startSystemResize(Qt.RightEdge)
    }

    MouseArea {
        x: 0
        y: 0
        width: root.width
        height: 12
        z: 20
        cursorShape: Qt.SizeVerCursor
        acceptedButtons: Qt.LeftButton
        onPressed: root.startSystemResize(Qt.TopEdge)
    }

    MouseArea {
        x: 0
        y: root.height - 12
        width: root.width
        height: 12
        z: 20
        cursorShape: Qt.SizeVerCursor
        acceptedButtons: Qt.LeftButton
        onPressed: root.startSystemResize(Qt.BottomEdge)
    }

    MouseArea {
        x: 0
        y: 0
        width: 18
        height: 18
        z: 30
        cursorShape: Qt.SizeFDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: root.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
    }

    MouseArea {
        x: root.width - 18
        y: 0
        width: 18
        height: 18
        z: 30
        cursorShape: Qt.SizeBDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: root.startSystemResize(Qt.TopEdge | Qt.RightEdge)
    }

    MouseArea {
        x: 0
        y: root.height - 18
        width: 18
        height: 18
        z: 30
        cursorShape: Qt.SizeBDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: root.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
    }

    MouseArea {
        x: root.width - 18
        y: root.height - 18
        width: 18
        height: 18
        z: 30
        cursorShape: Qt.SizeFDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: root.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
    }
}
