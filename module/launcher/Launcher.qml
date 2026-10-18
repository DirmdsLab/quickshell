import QtQuick
import QtQuick.Controls
import Quickshell

Item {
    id: root

    property bool open: false

    property bool commandMode: search.text.trim().startsWith(">")

    property string searchQuery: {
        const text = search.text.trim()

        return root.commandMode
            ? text.slice(1).trim().toLowerCase()
            : text.toLowerCase()
    }

    // Visible commands are listed first.
    // Set visible to false to keep a command hidden.
    property var commandEntries: [
        {
            id: "command-poweroff",
            kind: "command",
            name: "Poweroff",
            genericName: "Shut down the system",
            comment: "Power off Linux",
            icon: "system-shutdown",
            action: "poweroff",
            keywords: ["shutdown", "power", "off"]
        },
        {
            id: "command-restart",
            kind: "command",
            name: "Restart",
            genericName: "Restart the system",
            comment: "Reboot Linux",
            icon: "system-reboot",
            action: "restart",
            keywords: ["reboot", "restart"]
        },
        {
            id: "command-firmware",
            kind: "command",
            name: "Firmware Setup",
            genericName: "Reboot into firmware setup",
            comment: "Restart the system and enter UEFI/BIOS setup",
            icon: Qt.resolvedUrl("../../Icon/firmware.svg"),
            action: "custom",
            command: ["systemctl", "reboot", "--firmware-setup"],
            visible: true,
            keywords: ["firmware", "uefi", "bios", "reboot", "restart", "setup"]
        },
        {
            id: "command-logout",
            kind: "command",
            name: "Logout",
            genericName: "End the current session",
            comment: "Exit Hyprland",
            icon: "system-log-out",
            action: "logout",
            keywords: ["exit", "session", "logout"]
        },
        {
            id: "command-setting",
            kind: "command",
            name: "Setting",
            genericName: "Open system settings",
            comment: "Not implemented yet",
            icon: "preferences-system",
            action: "settings",
            keywords: ["settings", "configuration", "preferences"]
        },
        {
            id: "command-posi",
            kind: "command",
            name: "Posi",
            genericName: "Custom command",
            comment: "Hidden command entry",
            icon: "utilities-terminal",
            action: "custom",
            command: ["posi"],
            visible: false,
            keywords: ["posi"]
        }
    ]

    function toggle() {
        if (root.open)
            root.hide()
        else
            root.show()
    }

    function show() {
        if (!root.open)
            search.text = ""

        root.open = true
        root.focusSearch()
    }

    function hide() {
        root.open = false
        search.focus = false
    }

    function focusSearch() {
        if (root.open)
            search.forceActiveFocus()
    }

    function moveSelection(direction) {
        if (appList.count <= 0)
            return

        if (appList.currentIndex < 0) {
            appList.currentIndex = direction > 0
                ? 0
                : appList.count - 1
        } else {
            appList.currentIndex =
                (appList.currentIndex + direction + appList.count)
                % appList.count
        }

        appList.positionViewAtIndex(
            appList.currentIndex,
            ListView.Contain
        )
    }

    function launchSelected() {
        if (appList.count <= 0)
            return

        const selectedIndex = appList.currentIndex >= 0
            ? appList.currentIndex
            : 0

        const entry = filteredEntries.values[selectedIndex]

        if (entry)
            root.activateEntry(entry)
    }

    function activateEntry(entry) {
        if (!entry)
            return

        if (entry.kind === "command") {
            root.runCommand(entry)
            return
        }

        root.launchApplication(entry)
    }

    function launchApplication(application) {
        if (!application)
            return

        root.hide()

        try {
            application.execute()
        } catch (error) {
            console.error(
                "Failed to launch application:",
                application.name,
                error
            )
        }
    }

    function runCommand(entry) {
        if (!entry)
            return

        root.hide()

        try {
            switch (entry.action) {
            case "poweroff":
                Quickshell.execDetached([
                    "systemctl",
                    "poweroff"
                ])
                break

            case "restart":
                Quickshell.execDetached([
                    "systemctl",
                    "reboot"
                ])
                break

            case "logout":
                Quickshell.execDetached([
                    "hyprctl",
                    "dispatch",
                    "exit"
                ])
                break

            case "settings":
                console.info(
                    "Settings command is not implemented yet."
                )
                break

            case "custom":
                if (
                    Array.isArray(entry.command)
                    && entry.command.length > 0
                ) {
                    Quickshell.execDetached(entry.command)
                } else {
                    console.warn(
                        "Custom command has no executable:",
                        entry.name
                    )
                }
                break

            default:
                console.warn(
                    "Unknown command action:",
                    entry.action
                )
                break
            }
        } catch (error) {
            console.error(
                "Failed to execute command:",
                entry.name,
                error
            )
        }
    }


    property url missingIconSource: Qt.resolvedUrl("../../Icon/triangle-alert.svg")

    function entryIconSource(entry) {
        if (!entry)
            return root.missingIconSource
    
        if (entry.kind === "command") {
            switch (entry.action) {
            case "poweroff":
                return Qt.resolvedUrl("../../Icon/power.svg")
    
            case "restart":
                return Qt.resolvedUrl("../../Icon/restart.svg")
    
            case "logout":
                return Qt.resolvedUrl("../../Icon/log-out.svg")
    
            case "settings":
                return Qt.resolvedUrl("../../Icon/settings.svg")
    
            default: {
                const commandIcon = String(entry.icon || "").trim()
    
                if (!commandIcon)
                    return root.missingIconSource
    
                if (
                    commandIcon.startsWith("file://")
                    || commandIcon.startsWith("image://")
                    || commandIcon.startsWith("qrc:/")
                ) {
                    return commandIcon
                }
    
                if (commandIcon.startsWith("/"))
                    return "file://" + commandIcon
    
                if (commandIcon.endsWith(".svg"))
                    return Qt.resolvedUrl("../../Icon/" + commandIcon)
    
                return Quickshell.iconPath(commandIcon)
            }
            }
        }
    
        const name = String(entry.icon || "").trim()
    
        if (!name)
            return root.missingIconSource
    
        if (
            name.startsWith("file://")
            || name.startsWith("image://")
            || name.startsWith("qrc:/")
        ) {
            return name
        }
    
        if (name.startsWith("/"))
            return "file://" + name
    
        return Quickshell.iconPath(name)
    }

    width: parent
        ? Math.min(600, Math.max(280, parent.width - 32))
        : 600

    implicitHeight: content.implicitHeight + 36
    height: implicitHeight

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    property real offsetScale: root.open ? 0 : 1

    visible: root.open || offsetScale < 1

    opacity: 1 - offsetScale

    anchors.bottomMargin: -(height + 12) * offsetScale

    Behavior on offsetScale {
        NumberAnimation {
            duration: root.open ? 600 : 480
            easing.type: Easing.InOutCubic
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.open

        onActivated: {
            root.hide()
        }
    }

    Rectangle {
        anchors.fill: parent

        radius: 24
        topLeftRadius: 24
        topRightRadius: 24
        bottomLeftRadius: 0
        bottomRightRadius: 0

        antialiasing: true

        color: "#202020"

        border.width: 1
        border.color: "#404040"
    }

    Column {
        id: content

        x: 18
        y: 18

        width: root.width - 36
        spacing: 12

        TextField {
            id: search

            width: parent.width
            height: 50

            placeholderText: root.commandMode
                ? "Search commands..."
                : "Search applications..."

            color: "#FFFFFF"
            placeholderTextColor: "#888888"

            font.pixelSize: 16

            selectByMouse: true

            background: Rectangle {
                radius: 14

                color: "#303030"

                border.width: 1

                border.color: search.activeFocus
                    ? "#7188F8"
                    : "#444444"

                Behavior on border.color {
                    ColorAnimation {
                        duration: 220
                        easing.type: Easing.InOutCubic
                    }
                }
            }

            onTextChanged: {
                Qt.callLater(function() {
                    appList.currentIndex = appList.count > 0
                        ? 0
                        : -1

                    if (appList.count > 0) {
                        appList.positionViewAtIndex(
                            0,
                            ListView.Beginning
                        )
                    }
                })
            }

            Keys.priority: Keys.BeforeItem

            Keys.onEscapePressed: {
                root.hide()
                event.accepted = true
            }

            Keys.onDownPressed: {
                root.moveSelection(1)
                event.accepted = true
            }

            Keys.onUpPressed: {
                root.moveSelection(-1)
                event.accepted = true
            }

            Keys.onReturnPressed: {
                root.launchSelected()
                event.accepted = true
            }

            Keys.onEnterPressed: {
                root.launchSelected()
                event.accepted = true
            }
        }

        Item {
            id: resultsPanel

            width: parent.width

            height: appList.count === 0
                ? 42
                : Math.min(appList.count, 6) * 58
                  + (Math.min(appList.count, 6) - 1)
                  * appList.spacing

            Behavior on height {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            ScriptModel {
                id: filteredEntries

                objectProp: "id"

                values: {
                    const query = root.searchQuery

                    if (root.commandMode) {
                        const commands = root.commandEntries.filter(
                            function(entry) {
                                return entry.visible !== false
                            }
                        )

                        if (query.length === 0)
                            return commands

                        const terms = query.split(/\s+/)

                        return commands.filter(function(entry) {
                            const searchableText = [
                                entry.name,
                                entry.genericName,
                                entry.comment,
                                entry.id,
                                ...(entry.keywords || [])
                            ].join(" ").toLowerCase()

                            return terms.every(function(term) {
                                return searchableText.includes(term)
                            })
                        })
                    }

                    const applications = [
                        ...DesktopEntries.applications.values
                    ].filter(function(application) {
                        return application.name
                            && !application.noDisplay
                    }).sort(function(left, right) {
                        return left.name.localeCompare(right.name)
                    })

                    if (query.length === 0)
                        return applications

                    const terms = query.split(/\s+/)

                    return applications.filter(function(application) {
                        const searchableText = [
                            application.name,
                            application.genericName,
                            application.comment,
                            application.id,
                            application.execString,
                            ...(application.keywords || []),
                            ...(application.categories || [])
                        ].join(" ").toLowerCase()

                        return terms.every(function(term) {
                            return searchableText.includes(term)
                        })
                    })
                }
            }

            ListView {
                id: appList

                anchors.fill: parent

                model: filteredEntries

                spacing: 6
                clip: true

                visible: count > 0

                boundsBehavior: Flickable.StopAtBounds

                highlightFollowsCurrentItem: true
                highlightMoveDuration: 180
                highlightResizeDuration: 180

                highlight: Rectangle {
                    radius: 12

                    color: "#3A3A3A"

                    border.width: 1
                    border.color: "#7188F8"
                }

                onCountChanged: {
                    if (count === 0) {
                        currentIndex = -1
                    } else if (
                        currentIndex < 0
                        || currentIndex >= count
                    ) {
                        currentIndex = 0
                    }
                }

                delegate: Rectangle {
                    id: appDelegate

                    required property var modelData
                    required property int index

                    onModelDataChanged: {
                        appIcon.fallbackActive = false
                    }

                    width: appList.width
                    height: 58

                    radius: 12

                    color: "transparent"

                    Row {
                        anchors.fill: parent

                        anchors.leftMargin: 12
                        anchors.rightMargin: 12

                        spacing: 12


                        Image {
                            id: appIcon

                            property bool fallbackActive: false

                            width: 34
                            height: 34

                            anchors.verticalCenter: parent.verticalCenter

                            source: fallbackActive
                                ? root.missingIconSource
                                : root.entryIconSource(
                                    appDelegate.modelData
                                )

                            sourceSize.width: 34
                            sourceSize.height: 34

                            fillMode: Image.PreserveAspectFit

                            asynchronous: true
                            cache: true

                            onStatusChanged: {
                                if (
                                    status === Image.Error
                                    && !fallbackActive
                                ) {
                                    fallbackActive = true
                                }
                            }
                        }


                        Column {
                            width: parent.width - appIcon.width - 12

                            anchors.verticalCenter: parent.verticalCenter

                            spacing: 3

                            Text {
                                width: parent.width

                                text: appDelegate.modelData.name

                                color: "#FFFFFF"
                                font.pixelSize: 15

                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width

                                text: appDelegate.modelData.genericName
                                    || appDelegate.modelData.comment
                                    || appDelegate.modelData.id

                                color: "#999999"
                                font.pixelSize: 12

                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: mouseArea

                        anchors.fill: parent

                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: {
                            appList.currentIndex = appDelegate.index
                        }

                        onClicked: {
                            appList.currentIndex = appDelegate.index

                            root.activateEntry(
                                appDelegate.modelData
                            )
                        }
                    }
                }

                populate: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"

                            from: 0
                            to: 1

                            duration: 180
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            property: "scale"

                            from: 0.97
                            to: 1

                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"

                            from: 0
                            to: 1

                            duration: 170
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            property: "scale"

                            from: 0.97
                            to: 1

                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"

                            to: 0

                            duration: 110
                            easing.type: Easing.InCubic
                        }

                        NumberAnimation {
                            property: "scale"

                            to: 0.96

                            duration: 110
                            easing.type: Easing.InCubic
                        }
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "y"

                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Component.onCompleted: {
                    currentIndex = count > 0 ? 0 : -1
                }
            }

            Text {
                anchors.fill: parent

                visible: appList.count === 0

                text: root.commandMode
                    ? (
                        root.searchQuery.length > 0
                            ? "No commands found"
                            : "No commands available"
                    )
                    : (
                        root.searchQuery.length > 0
                            ? "No applications found"
                            : "No desktop applications available"
                    )

                color: "#909090"
                font.pixelSize: 14

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
