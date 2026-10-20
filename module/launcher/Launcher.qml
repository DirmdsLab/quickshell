import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool open: false

    property var pendingCommand: null
    property int confirmationSeconds: 15
    property bool confirmationYesSelected: false

    property bool bootNextMode: false
    property var bootNextEntries: []
    property bool bootNextLoading: false
    property bool bootNextAuthorizing: false
    property bool bootNextRestartConfirmationPending: false
    property bool bootNextApplied: false
    property string bootNextSelectedId: ""
    property var bootNextPendingEntry: null
    property string bootNextVerifyOutput: ""
    property string bootNextError: ""
    property string bootNextStderr: ""
    property string bootNextOperation: ""
    property string bootNextScriptPath: Quickshell.shellDir + "/scripts/os/bootnext.sh"
    property string envExecutable: "/usr/bin/env"
    property string pkexecExecutable: "/run/wrappers/bin/pkexec"
    property string shellPath: String(
        Quickshell.env("PATH")
        || "/run/current-system/sw/bin:/run/wrappers/bin:/usr/bin:/bin"
    )

    property bool commandMode: search.text.trim().startsWith(">")

    property string searchQuery: {
        const text = search.text.trim()

        return root.commandMode
            ? text.slice(1).trim().toLowerCase()
            : text.toLowerCase()
    }

    signal settingsRequested()

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
            id: "command-next-boot",
            kind: "command",
            name: "Next Boot",
            genericName: "Choose an operating system for the next boot",
            comment: "Select an EFI boot entry and reboot",
            icon: Qt.resolvedUrl("../../Icon/bootnext.svg"),
            action: "bootnext",
            keywords: ["boot", "next", "efi", "uefi", "operating system", "os"]
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
            name: "Settings",
            genericName: "System settings",
            comment: "Open the custom system settings interface",
            icon: "preferences-system",
            action: "settings",
            keywords: ["settings", "configuration", "preferences", "system"]
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
        if (!root.open) {
            search.text = ""
            root.bootNextMode = false
            root.bootNextError = ""
        }

        root.open = true
        root.focusSearch()
    }

    function hide() {
        root.open = false
        root.bootNextMode = false
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

        if (entry.kind === "bootEntry") {
            root.requestConfirmation(entry)
            return
        }

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

    function requiresConfirmation(entry) {
        if (!entry)
            return false

        return entry.action === "poweroff"
            || entry.action === "restart"
            || entry.action === "logout"
            || entry.id === "command-firmware"
            || entry.kind === "bootEntry"
    }

    function confirmationTitle(entry) {
        if (!entry)
            return "Confirm action"

        if (entry.kind === "bootEntry") {
            if (
                root.bootNextApplied
                && root.bootNextSelectedId === String(entry.bootId || "").toUpperCase()
            ) {
                return "Restart now to boot into " + entry.name + "?"
            }

            return "Boot next to " + entry.name + "?"
        }

        if (entry.id === "command-firmware")
            return "Restart into firmware setup?"

        switch (entry.action) {
        case "poweroff":
            return "Shut down the system?"

        case "restart":
            return "Restart the system?"

        case "logout":
            return "Log out of the current session?"

        default:
            return "Confirm action"
        }
    }

    function confirmationDescription(entry) {
        if (entry && entry.kind === "bootEntry") {
            if (
                root.bootNextApplied
                && root.bootNextSelectedId === String(entry.bootId || "").toUpperCase()
            ) {
                return "BootNext is verified for this EFI entry. Confirm to restart now and boot into this operating system. Choosing No leaves it selected for your next reboot."
            }

            return "Authorize setting this EFI entry as BootNext. After authorization, BootNext will be verified and you will be asked to confirm the restart."
        }

        return "Are you sure you want to continue? This action may close your session or shut down the system."
    }

    function requestConfirmation(entry) {
        if (!entry)
            return

        confirmationTimer.stop()
        restartConfirmationDelay.stop()
        root.bootNextRestartConfirmationPending = false

        if (entry.kind === "bootEntry") {
            root.bootNextApplied = false
            root.bootNextSelectedId = ""
            root.bootNextPendingEntry = entry
        }

        root.pendingCommand = entry
        root.confirmationSeconds = 15
        root.confirmationYesSelected = false
        confirmationPopup.open()
        confirmationTimer.start()
    }

    function requestRestartConfirmation(entry) {
        if (!entry)
            return

        root.bootNextAuthorizing = false
        root.bootNextMode = false
        root.bootNextError = ""
        root.pendingCommand = entry
        root.confirmationSeconds = 15
        root.confirmationYesSelected = false
        root.bootNextRestartConfirmationPending = true

        if (!confirmationPopup.visible)
            restartConfirmationDelay.restart()
    }

    function openRestartConfirmation() {
        if (
            !root.bootNextRestartConfirmationPending
            || !root.pendingCommand
            || !root.bootNextApplied
        ) {
            return
        }

        restartConfirmationDelay.stop()
        root.bootNextRestartConfirmationPending = false
        root.open = true
        confirmationPopup.open()
        confirmationTimer.restart()
    }

    function showBootNextFailure(message) {
        root.bootNextAuthorizing = false
        root.bootNextRestartConfirmationPending = false
        restartConfirmationDelay.stop()
        root.bootNextOperation = ""
        root.bootNextApplied = false
        root.bootNextSelectedId = ""
        root.bootNextError = String(message || "Failed to set or verify the next boot entry.")
        root.bootNextMode = true
        root.bootNextLoading = false
        root.open = true
        root.pendingCommand = null
        confirmationTimer.stop()
        if (confirmationPopup.visible)
            confirmationPopup.close()
        console.error("Next Boot failed:", root.bootNextError)
        Qt.callLater(function() {
            if (root.open)
                root.focusSearch()
        })
    }

    function requestBootNextMenu() {
        root.bootNextMode = true
        root.bootNextEntries = []
        root.bootNextLoading = true
        root.bootNextError = ""
        root.bootNextStderr = ""
        root.bootNextOperation = "list"
        search.text = ""
        root.open = true

        bootNextProcess.exec([
            root.envExecutable,
            "bash",
            root.bootNextScriptPath,
            "list-ui"
        ])

        Qt.callLater(function() {
            if (root.open && root.bootNextMode)
                search.forceActiveFocus()
        })
    }

    function exitBootNextMenu() {
        root.bootNextMode = false
        root.bootNextLoading = false
        root.bootNextError = ""
        search.text = ">"
        root.focusSearch()
    }

    function bootEntryIconSource(label) {
        const normalizedLabel = String(label || "").toLowerCase()

        if (
            normalizedLabel.includes("windows boot manager")
            || normalizedLabel.includes("windows")
        ) {
            return Qt.resolvedUrl("../../Icon/windows.svg")
        }

        const linuxKeywords = [
            "linux",
            "grub",
            "nixos",
            "cachy",
            "arch",
            "ubuntu",
            "fedora",
            "debian",
            "opensuse",
            "open suse",
            "manjaro",
            "endeavour",
            "systemd-boot",
            "pop!_os",
            "elementary os",
            "mint"
        ]

        if (linuxKeywords.some(function(keyword) {
            return normalizedLabel.includes(keyword)
        })) {
            return Qt.resolvedUrl("../../Icon/linux.svg")
        }

        return root.missingIconSource
    }

    function handleBootNextOutput(output) {
        if (root.bootNextOperation === "set") {
            root.bootNextVerifyOutput = String(output || "")
            return
        }

        if (root.bootNextOperation !== "list")
            return

        const entries = []
        const lines = String(output || "").split(/\r?\n/)

        for (const line of lines) {
            if (!line.trim())
                continue

            const fields = line.split("\t")
            if (fields.length < 5 || !/^[0-9A-Fa-f]{4}$/.test(fields[0]))
                continue

            const bootId = fields[0].toUpperCase()
            const label = fields[1].trim() || ("Boot " + bootId)
            const partition = fields[2]
            const partUuid = fields[3]
            const status = fields.slice(4).join(" ").trim() || "-"
            const isCurrent = /\bcurrent\b/i.test(status)
            const details = status !== "-"
                ? status + " · Boot " + bootId + " · Partition " + partition
                : "Boot " + bootId + " · Partition " + partition

            entries.push({
                id: "boot-entry-" + bootId,
                kind: "bootEntry",
                name: label,
                genericName: details,
                comment: status === "-" ? "EFI boot entry" : status,
                icon: root.bootEntryIconSource(label),
                bootId: bootId,
                partition: partition,
                partUuid: partUuid,
                status: status,
                isCurrent: isCurrent,
                keywords: [bootId, partition, partUuid, status]
            })
        }

        root.bootNextEntries = entries
        root.bootNextLoading = false

        if (entries.length === 0 && !root.bootNextError)
            root.bootNextError = "No active EFI boot entries were found."
    }

    function handleBootNextExit(exitCode) {
        const operation = root.bootNextOperation

        if (operation === "list") {
            root.bootNextOperation = ""
            root.bootNextLoading = false

            if (exitCode !== 0) {
                root.bootNextError = root.bootNextStderr.length > 0
                    ? root.bootNextStderr
                    : "Failed to read EFI boot entries. Check the bootnext.sh script and required commands."
            } else if (root.bootNextEntries.length === 0 && !root.bootNextError) {
                root.bootNextError = "No active EFI boot entries were found."
            }

            return
        }

        if (operation === "set") {
            root.bootNextAuthorizing = false

            if (exitCode !== 0) {
                root.showBootNextFailure(
                    root.bootNextStderr.length > 0
                        ? root.bootNextStderr
                        : "Authorization was cancelled or efibootmgr failed. BootNext was not verified."
                )
                return
            }

            const match = /^BootNext:[\t ]*([0-9A-Fa-f]{4})/m.exec(
                root.bootNextVerifyOutput
            )
            const expectedId = String(
                root.bootNextPendingEntry ? root.bootNextPendingEntry.bootId : ""
            ).toUpperCase()

            if (!match || match[1].toUpperCase() !== expectedId) {
                root.showBootNextFailure(
                    "efibootmgr completed, but BootNext could not be verified for Boot" + expectedId + "."
                )
                return
            }

            root.bootNextOperation = ""
            root.bootNextApplied = true
            root.bootNextSelectedId = expectedId
            root.bootNextError = ""
            root.requestRestartConfirmation(root.bootNextPendingEntry)
            return
        }

        root.bootNextOperation = ""
    }

    function executeBootNext(entry) {
        if (!entry || !/^[0-9A-F]{4}$/.test(String(entry.bootId || ""))) {
            root.showBootNextFailure("Invalid EFI boot entry selection.")
            return
        }

        root.bootNextPendingEntry = entry
        root.bootNextApplied = false
        root.bootNextSelectedId = ""
        root.bootNextAuthorizing = true
        root.bootNextOperation = "set"
        root.bootNextStderr = ""
        root.bootNextVerifyOutput = ""

        // Release the launcher focus grab so the Polkit agent can receive keyboard input.
        root.hide()

        // Set BootNext and read it back in the same privileged process.
        bootNextProcess.exec([
            root.pkexecExecutable,
            root.envExecutable,
            "PATH=" + root.shellPath,
            "bash",
            "-c",
            "set -euo pipefail; "
                + "export PATH=/run/current-system/sw/bin:/run/wrappers/bin:/usr/bin:/bin; "
                + "command -v efibootmgr >/dev/null; "
                + "efibootmgr --bootnext \"$1\"; efibootmgr --verbose",
            "bootnext",
            String(entry.bootId).toUpperCase()
        ])
    }

    function cancelConfirmation() {
        const entry = root.pendingCommand

        confirmationTimer.stop()
        restartConfirmationDelay.stop()
        root.bootNextRestartConfirmationPending = false
        root.pendingCommand = null

        if (confirmationPopup.visible)
            confirmationPopup.close()

        if (entry && entry.kind === "bootEntry") {
            root.bootNextAuthorizing = false
            root.hide()
        }
    }

    function confirmPendingCommand() {
        const entry = root.pendingCommand

        if (!entry)
            return

        confirmationTimer.stop()
        restartConfirmationDelay.stop()
        root.bootNextRestartConfirmationPending = false
        root.pendingCommand = null

        confirmationPopup.close()

        if (entry.kind === "bootEntry") {
            if (
                root.bootNextApplied
                && root.bootNextSelectedId === String(entry.bootId || "").toUpperCase()
            ) {
                root.restartWithBootNext(entry)
            } else {
                root.executeBootNext(entry)
            }
            return
        }

        root.executeCommand(entry)
    }

    function restartWithBootNext(entry) {
        const expectedId = String(entry ? entry.bootId : "").toUpperCase()

        if (
            !entry
            || !root.bootNextApplied
            || root.bootNextSelectedId !== expectedId
        ) {
            root.showBootNextFailure("Restart was blocked because BootNext has not been verified.")
            return
        }

        root.bootNextAuthorizing = false
        root.hide()

        Quickshell.execDetached([
            "systemctl",
            "reboot"
        ])
    }


    function runCommand(entry) {
       if (!entry)
           return

       if (entry.action === "settings") {
           root.settingsRequested()
           return
       }

       if (entry.action === "bootnext") {
           root.requestBootNextMenu()
           return
       }

       if (root.requiresConfirmation(entry)) {
           root.requestConfirmation(entry)
           return
       }

       root.executeCommand(entry)
    }

    function executeCommand(entry) {
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
        enabled: root.open && !confirmationPopup.visible

        onActivated: {
            if (root.bootNextMode)
                root.exitBootNextMenu()
            else
                root.hide()
        }
    }

    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        enabled: confirmationPopup.visible

        onActivated: root.confirmationYesSelected = false
    }

    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        enabled: confirmationPopup.visible

        onActivated: root.confirmationYesSelected = true
    }

    Shortcut {
        sequence: "Tab"
        context: Qt.ApplicationShortcut
        enabled: confirmationPopup.visible

        onActivated: root.confirmationYesSelected = !root.confirmationYesSelected
    }

    Shortcut {
        sequence: "Return"
        context: Qt.ApplicationShortcut
        enabled: confirmationPopup.visible

        onActivated: {
            if (root.confirmationYesSelected)
                root.confirmPendingCommand()
            else
                root.cancelConfirmation()
        }
    }

    Shortcut {
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        enabled: confirmationPopup.visible

        onActivated: {
            if (root.confirmationYesSelected)
                root.confirmPendingCommand()
            else
                root.cancelConfirmation()
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: confirmationPopup.visible

        onActivated: root.cancelConfirmation()
    }

    Process {
        id: bootNextProcess

        command: []

        stdout: StdioCollector {
            onStreamFinished: root.handleBootNextOutput(this.text)
        }

        stderr: StdioCollector {
            onStreamFinished: root.bootNextStderr = this.text.trim()
        }

        onExited: function(exitCode, exitStatus) {
            root.handleBootNextExit(exitCode)
        }
    }

    Timer {
        id: confirmationTimer

        interval: 1000
        repeat: true

        onTriggered: {
            if (!root.pendingCommand) {
                stop()
                return
            }

            if (root.confirmationSeconds <= 1) {
                root.confirmationSeconds = 0
                stop()
                root.confirmPendingCommand()
                return
            }

            root.confirmationSeconds--
        }
    }

    Timer {
        id: restartConfirmationDelay
        interval: 200
        repeat: false

        onTriggered: root.openRestartConfirmation()
    }

    Item {
        id: launcherPanelBackground

        anchors.fill: parent
        visible: !confirmationPopup.visible && !root.bootNextAuthorizing

        readonly property real sideCurve: 28
        readonly property real edgeBleed: 2

        Canvas {
            id: launcherBackgroundCanvas

            x: -launcherPanelBackground.sideCurve
            y: 0
            width: root.width + launcherPanelBackground.sideCurve * 2
            height: root.height + launcherPanelBackground.edgeBleed
            antialiasing: true

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const context = getContext("2d")
                const left = launcherPanelBackground.sideCurve
                const right = left + root.width
                const bottom = height
                const topRadius = 24
                const bottomCurve = launcherPanelBackground.sideCurve

                context.clearRect(0, 0, width, height)

                // Extend the bottom corners outward to meet the screen edge.
                context.beginPath()
                context.moveTo(0, bottom)
                context.quadraticCurveTo(
                    left, bottom,
                    left, bottom - bottomCurve
                )

                // Normal top-left and top-right rounded corners.
                context.lineTo(left, topRadius)
                context.quadraticCurveTo(left, 0, left + topRadius, 0)
                context.lineTo(right - topRadius, 0)
                context.quadraticCurveTo(right, 0, right, topRadius)

                // Mirrored outward curve on the bottom-right corner.
                context.lineTo(right, bottom - bottomCurve)
                context.quadraticCurveTo(
                    right, bottom,
                    width, bottom
                )
                context.closePath()

                context.fillStyle = "#202020"
                context.fill()

                // Keep the screen-edge seam free of an extra border.
                context.beginPath()
                context.moveTo(0, bottom)
                context.quadraticCurveTo(
                    left, bottom,
                    left, bottom - bottomCurve
                )
                context.lineTo(left, topRadius)
                context.quadraticCurveTo(left, 0, left + topRadius, 0)
                context.lineTo(right - topRadius, 0)
                context.quadraticCurveTo(right, 0, right, topRadius)
                context.lineTo(right, bottom - bottomCurve)
                context.quadraticCurveTo(
                    right, bottom,
                    width, bottom
                )

                context.strokeStyle = "#404040"
                context.lineWidth = 1
                context.stroke()
            }
        }
    }

    Column {
        id: content

        visible: !confirmationPopup.visible && !root.bootNextAuthorizing

        x: 18
        y: 18

        width: root.width - 36
        spacing: 12

        TextField {
            id: search

            width: parent.width
            height: 50

            placeholderText: root.bootNextMode
                ? "Select or search an operating system..."
                : root.commandMode
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
                if (root.bootNextMode)
                    root.exitBootNextMenu()
                else
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

        Text {
            width: parent.width
            visible: root.bootNextMode && root.bootNextError.length > 0
            text: root.bootNextError
            color: "#ff9b9b"
            font.pixelSize: 12
            wrapMode: Text.Wrap
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

                    if (root.bootNextMode) {
                        const entries = root.bootNextEntries

                        if (query.length === 0)
                            return entries

                        const terms = query.split(/\s+/)

                        return entries.filter(function(entry) {
                            const searchableText = [
                                entry.name,
                                entry.genericName,
                                entry.comment,
                                entry.bootId,
                                entry.partition,
                                entry.partUuid,
                                entry.status,
                                ...(entry.keywords || [])
                            ].join(" ").toLowerCase()

                            return terms.every(function(term) {
                                return searchableText.includes(term)
                            })
                        })
                    }

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

                                color: appDelegate.modelData.isCurrent
                                    ? "#9EEAF3"
                                    : "#999999"
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

                text: root.bootNextMode
                    ? (root.bootNextLoading
                        ? "Loading EFI boot entries..."
                        : root.bootNextError || "No EFI boot entries found")
                    : root.commandMode
                        ? (root.searchQuery.length > 0
                            ? "No commands found"
                            : "No commands available")
                        : (root.searchQuery.length > 0
                            ? "No applications found"
                            : "No desktop applications available")

                color: "#909090"
                font.pixelSize: 14

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }


    Popup {
        id: confirmationPopup

        parent: Overlay.overlay

        width: 440
        height: 250

        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)

        padding: 24

        modal: true
        focus: true

        closePolicy: Popup.NoAutoClose

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 150
                easing.type: Easing.InCubic
            }
        }

        onOpened: {
            Qt.callLater(function() {
                if (confirmationPopup.visible)
                    confirmationContent.forceActiveFocus()
            })
        }

        Overlay.modal: Rectangle {
            color: "#99000000"
        }

        background: Rectangle {
            radius: 22
            color: "#171d1d"

            border.width: 1
            border.color: "#384141"
        }

        onClosed: {
            if (root.bootNextRestartConfirmationPending) {
                root.openRestartConfirmation()
                return
            }

            confirmationTimer.stop()

            if (root.open && !root.bootNextAuthorizing) {
                Qt.callLater(function() {
                    if (root.open && !confirmationPopup.visible && !root.bootNextAuthorizing)
                        root.focusSearch()
                })
            }
        }

        contentItem: Column {
            id: confirmationContent

            width: 392
            spacing: 12
            focus: true
            Keys.priority: Keys.BeforeItem

            Keys.onPressed: function(event) {
                if (!confirmationPopup.visible)
                    return

                switch (event.key) {
                case Qt.Key_Left:
                case Qt.Key_Up:
                    root.confirmationYesSelected = false
                    event.accepted = true
                    break

                case Qt.Key_Right:
                case Qt.Key_Down:
                    root.confirmationYesSelected = true
                    event.accepted = true
                    break

                case Qt.Key_Tab:
                    root.confirmationYesSelected = !root.confirmationYesSelected
                    event.accepted = true
                    break

                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (root.confirmationYesSelected)
                        root.confirmPendingCommand()
                    else
                        root.cancelConfirmation()
                    event.accepted = true
                    break

                case Qt.Key_Escape:
                    root.cancelConfirmation()
                    event.accepted = true
                    break
                }
            }

            Text {
                width: parent.width

                text: root.confirmationTitle(
                    root.pendingCommand
                )

                color: "#edf4f4"
                font.pixelSize: 21
                font.weight: Font.DemiBold

                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width

                text: root.confirmationDescription(root.pendingCommand)

                color: "#aab8b8"
                font.pixelSize: 13

                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width

                text: "Automatically confirming in "
                    + root.confirmationSeconds
                    + " seconds"

                color: "#9eeaf3"
                font.pixelSize: 13
            }

            Item {
                width: 1
                height: 4
            }

            Row {
                width: parent.width
                spacing: 12

                Button {
                    id: noButton

                    width: (parent.width - parent.spacing) / 2
                    height: 44

                    text: "No"
                    focusPolicy: Qt.StrongFocus

                    onClicked: {
                        root.cancelConfirmation()
                    }

                    background: Rectangle {
                        radius: 12

                        color: noButton.down
                            ? "#3a4747"
                            : !root.confirmationYesSelected
                                ? "#34484a"
                                : "#293333"

                        border.width: 1
                        border.color: !root.confirmationYesSelected
                            ? "#9eeaf3"
                            : "#465252"
                    }

                    contentItem: Text {
                        text: noButton.text

                        color: "#e5eeee"
                        font.pixelSize: 14
                        font.weight: Font.Medium

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: yesButton

                    width: (parent.width - parent.spacing) / 2
                    height: 44

                    text: "Yes"
                    focusPolicy: Qt.StrongFocus

                    onClicked: {
                        root.confirmPendingCommand()
                    }

                    background: Rectangle {
                        radius: 12

                        color: yesButton.down
                            ? "#83d4df"
                            : root.confirmationYesSelected
                                ? "#83d4df"
                                : "#293333"

                        border.width: root.confirmationYesSelected ? 1 : 0
                        border.color: "#9eeaf3"
                    }

                    contentItem: Text {
                        text: yesButton.text

                        color: root.confirmationYesSelected
                            ? "#172222"
                            : "#aab8b8"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }


}
