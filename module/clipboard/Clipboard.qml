import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool open: false
    property bool showActions: false
    property string helperPath: Quickshell.shellPath("scripts/clipboard-helper")
    property var historyEntries: []
    property var imagePaths: ({})
    property var activeEntry: null
    property int actionIndex: 0
    property string pendingAction: ""
    property bool closeAfterAction: false
    property string actionReturnText: ""
    property bool suppressSearchChanges: false

    property int requestSequence: 0
    property int latestRequestId: 0
    property var activeRequest: null
    property var queuedRequest: null
    property bool hasQueuedRequest: false
    property bool isLoadingMore: false
    property int loadedOffset: 0
    property bool showMoreAvailable: false
    property int baseMaxId: 0
    property int consecutiveEmptyRanges: 0
    property string lastInputMode: "history"

    property bool commandMode: search.text.trim().startsWith(">")
    property bool pinMode: search.text.trim().startsWith("!")
    property string searchQuery: {
        const value = search.text.trim()
        return value.startsWith(">")
            ? value.slice(1).trim().toLowerCase()
            : ""
    }

    property var commandEntries: [
        {
            id: "delete-range-10",
            kind: "command",
            name: "Delete last 10",
            genericName: "Delete the 10 most recent clipboard entries",
            comment: "Delete clipboard entries",
            action: "delete-range",
            count: 10,
            icon: Qt.resolvedUrl("../../Icon/trash.svg"),
            keywords: ["delete", "remove", "10", "last", "recent"]
        },
        {
            id: "delete-range-20",
            kind: "command",
            name: "Delete last 20",
            genericName: "Delete the 20 most recent clipboard entries",
            comment: "Delete clipboard entries",
            action: "delete-range",
            count: 20,
            icon: Qt.resolvedUrl("../../Icon/trash.svg"),
            keywords: ["delete", "remove", "20", "last", "recent"]
        },
        {
            id: "delete-range-30",
            kind: "command",
            name: "Delete last 30",
            genericName: "Delete the 30 most recent clipboard entries",
            comment: "Delete clipboard entries",
            action: "delete-range",
            count: 30,
            icon: Qt.resolvedUrl("../../Icon/trash.svg"),
            keywords: ["delete", "remove", "30", "last", "recent"]
        },
        {
            id: "delete-range-50",
            kind: "command",
            name: "Delete last 50",
            genericName: "Delete the 50 most recent clipboard entries",
            comment: "Delete clipboard entries",
            action: "delete-range",
            count: 50,
            icon: Qt.resolvedUrl("../../Icon/trash.svg"),
            keywords: ["delete", "remove", "50", "last", "recent"]
        },
        {
            id: "delete-range-all",
            kind: "command",
            name: "Delete all",
            genericName: "Delete all clipboard entries and pins",
            comment: "Clear clipboard history",
            action: "delete-range",
            count: "all",
            icon: Qt.resolvedUrl("../../Icon/trash.svg"),
            keywords: ["delete", "remove", "all", "clear", "wipe"]
        }
    ]

    property var actionEntries: [
        {
            id: "paste",
            name: "Paste",
            genericName: "Copy this entry to the system clipboard",
            action: "sel",
            icon: Qt.resolvedUrl("../../Icon/clipboard-pen.svg")
        },
        {
            id: "pin",
            name: "Pin",
            genericName: "Keep this entry in the pinned list",
            action: "pin",
            icon: Qt.resolvedUrl("../../Icon/pin.svg")
        },
        {
            id: "delete",
            name: "Delete",
            genericName: "Remove this entry from clipboard history",
            action: "del",
            icon: Qt.resolvedUrl("../../Icon/trash.svg")
        }
    ]

    property url missingIconSource: Qt.resolvedUrl("../../Icon/triangle-alert.svg")

    property var filteredEntries: {
        if (root.commandMode) {
            const commands = root.commandEntries
            const query = root.searchQuery

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

        return root.historyEntries
    }

    property var displayEntries: {
        const entries = root.filteredEntries.slice()

        if (
            !root.commandMode
            && !root.pinMode
            && search.text.trim().length === 0
            && root.showMoreAvailable
        ) {
            entries.push(root.createShowMoreEntry())
        }

        return entries
    }

    function serializeEntry(entry) {
        const serializableEntry = Object.assign({}, entry)

        if (serializableEntry.icon !== undefined)
            serializableEntry.icon = String(serializableEntry.icon)

        return JSON.stringify(serializableEntry)
    }

    function appendDisplayEntry(entry) {
        displayModel.append({
            entryKind: String(entry.kind || "history"),
            payload: root.serializeEntry(entry)
        })
    }

    function createShowMoreEntry() {
        return {
            id: "clipboard-show-more",
            kind: "show-more",
            name: "Show more",
            genericName: "Load entries " + (root.loadedOffset + 1)
                + "-" + (root.loadedOffset + 10),
            comment: "Load the next clipboard range",
            icon: Qt.resolvedUrl("../../Icon/more.svg")
        }
    }

    function shouldShowMoreEntry() {
        return !root.commandMode
            && !root.pinMode
            && search.text.trim().length === 0
            && root.showMoreAvailable
    }

    function rebuildDisplayModel() {
        displayModel.clear()

        let entries = []

        if (search.text.trim().startsWith(">")) {
            const query = search.text.trim().slice(1).trim().toLowerCase()
            const terms = query.length > 0 ? query.split(/\s+/) : []

            entries = root.commandEntries.filter(function(entry) {
                if (terms.length === 0)
                    return true

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
        } else {
            entries = root.historyEntries.slice()

            if (root.shouldShowMoreEntry())
                entries.push(root.createShowMoreEntry())
        }

        for (let index = 0; index < entries.length; index++)
            root.appendDisplayEntry(entries[index])
    }

    function removeTrailingShowMoreEntry() {
        if (
            displayModel.count > 0
            && displayModel.get(displayModel.count - 1).entryKind === "show-more"
        ) {
            displayModel.remove(displayModel.count - 1)
        }
    }

    function appendHistoryMoreEntries(entries) {
        if (entries.length === 0) {
            if (!root.shouldShowMoreEntry())
                root.removeTrailingShowMoreEntry()
            return
        }

        root.removeTrailingShowMoreEntry()

        for (let index = 0; index < entries.length; index++)
            root.appendDisplayEntry(entries[index])

        if (root.shouldShowMoreEntry())
            root.appendDisplayEntry(root.createShowMoreEntry())
    }

    function displayEntryAt(index) {
        if (index < 0 || index >= displayModel.count)
            return null

        try {
            return JSON.parse(displayModel.get(index).payload)
        } catch (error) {
            console.error("Failed to decode clipboard display entry:", error)
            return null
        }
    }

    function currentInputMode() {
        if (root.commandMode)
            return "command"
        if (root.pinMode)
            return "pin"
        return search.text.trim().length === 0 ? "history" : "search"
    }

    function scrollToIndexSmooth(index) {
        if (index < 0 || index >= appList.count)
            return

        Qt.callLater(function() {
            if (index < 0 || index >= appList.count)
                return

            const previousContentY = appList.contentY
            appList.positionViewAtIndex(index, ListView.Contain)
            const targetContentY = appList.contentY
            appList.contentY = previousContentY
            appList.currentIndex = index

            if (Math.abs(targetContentY - previousContentY) < 1)
                return

            listScrollAnimation.stop()
            listScrollAnimation.from = previousContentY
            listScrollAnimation.to = targetContentY
            listScrollAnimation.start()
        })
    }

    function toggle() {
        if (root.open)
            root.hide()
        else
            root.show()
    }

    function show() {
        searchTimer.stop()
        root.showActions = false
        root.activeEntry = null
        root.actionIndex = 0
        root.historyEntries = []
        root.imagePaths = ({})
        root.loadedOffset = 0
        root.showMoreAvailable = false
        root.isLoadingMore = false
        root.baseMaxId = 0
        root.consecutiveEmptyRanges = 0
        root.lastInputMode = "history"
        displayModel.clear()

        root.invalidatePendingRequests()

        root.suppressSearchChanges = true
        search.text = ""
        root.suppressSearchChanges = false
        root.open = true
        root.requestInitialHistory()
        root.focusSearch()
    }

    function hide() {
        searchTimer.stop()
        root.open = false
        root.showActions = false
        root.activeEntry = null
        search.focus = false
    }

    function focusSearch() {
        if (root.open)
            search.forceActiveFocus()
    }

    function invalidatePendingRequests() {
        root.requestSequence += 1
        root.latestRequestId = root.requestSequence
        root.queuedRequest = null
        root.hasQueuedRequest = false
        root.isLoadingMore = false
    }

    function requestList(args, mode, resetEntries, offsetEnd) {
        root.requestSequence += 1

        const request = {
            id: root.requestSequence,
            args: args,
            mode: mode,
            resetEntries: resetEntries,
            offsetEnd: offsetEnd || 0
        }

        root.latestRequestId = request.id

        if (listProcess.running || indexProcess.running) {
            root.queuedRequest = request
            root.hasQueuedRequest = true
            return
        }

        root.startListRequest(request)
    }

    function startListRequest(request) {
        root.activeRequest = request
        listProcess.command = ["bash", root.helperPath].concat(request.args)
        listProcess.running = true
    }

    function requestInitialHistory() {
        root.loadedOffset = 0
        root.showMoreAvailable = false
        root.baseMaxId = 0
        root.consecutiveEmptyRanges = 0
        root.requestList(
            ["list", "range", "0-10"],
            "history-initial",
            true,
            10
        )
    }

    function loadMore() {
        if (!root.showMoreAvailable || root.isLoadingMore)
            return

        const rangeStart = root.loadedOffset
        const rangeEnd = rangeStart + 10

        root.isLoadingMore = true
        root.requestList(
            ["list", "range", String(rangeStart) + "-" + String(rangeEnd)],
            "history-more",
            false,
            rangeEnd
        )
    }

    function runSearch() {
        if (!root.open || root.showActions || root.commandMode)
            return

        const value = search.text.trim()

        if (root.pinMode) {
            root.historyEntries = []
            root.imagePaths = ({})
            displayModel.clear()
            root.loadedOffset = 0
            root.showMoreAvailable = false
            root.requestList(["list", "pin", "all"], "pins", true, 0)
            return
        }

        if (value.length === 0) {
            root.historyEntries = []
            root.imagePaths = ({})
            displayModel.clear()
            root.requestInitialHistory()
            return
        }

        root.historyEntries = []
        root.imagePaths = ({})
        root.loadedOffset = 0
        root.showMoreAvailable = false
        displayModel.clear()

        const imageTypeQuery = /^type\s+img$/i.test(value)
        const textTypeQuery = /^type\s+text$/i.test(value)

        if (imageTypeQuery) {
            root.requestList(["search", "type", "img"], "search", true, 0)
        } else if (textTypeQuery) {
            root.requestList(["search", "type", "text"], "search", true, 0)
        } else {
            root.requestList(["search", value], "search", true, 0)
        }
    }

    function parseListOutput(output) {
        const request = root.activeRequest

        if (!request || request.id !== root.latestRequestId)
            return

        const parsedEntries = []
        const lines = output.split(/\r?\n/)
        const rowPattern = /^\s*(\d+)\s*\|\s*(.*?)\s*\|\s*(img|text)\s*$/i

        for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
            const match = rowPattern.exec(lines[lineIndex])

            if (!match)
                continue

            const entryId = String(match[1]).trim()
            const preview = String(match[2] || "").trim()
            const entryType = String(match[3] || "text").trim().toLowerCase()
            const isImage = entryType === "img"

            parsedEntries.push({
                id: entryId,
                kind: "history",
                type: entryType,
                preview: preview,
                isImage: isImage,
                name: isImage ? "Image" : (preview || "Empty clipboard item"),
                genericName: "ID " + entryId + " · " + (isImage ? "Image" : "Text"),
                comment: isImage ? "Image clipboard item" : "Clipboard text"
            })
        }

        // Keep the newest clipboard entries at the top for every list mode.
        parsedEntries.sort(function(left, right) {
            return Number(right.id) - Number(left.id)
        })

        if (request.mode === "history-initial") {
            root.historyEntries = parsedEntries
            root.loadedOffset = request.offsetEnd
            root.baseMaxId = parsedEntries.length > 0
                ? Number(parsedEntries[0].id)
                : 0
            root.consecutiveEmptyRanges = 0
            root.showMoreAvailable = parsedEntries.length > 0
                && root.baseMaxId > request.offsetEnd
            root.rebuildDisplayModel()
        } else if (request.mode === "history-more") {
            const existingIds = ({})
            const previousEntryCount = root.historyEntries.length

            for (let existingIndex = 0; existingIndex < root.historyEntries.length; existingIndex++)
                existingIds[String(root.historyEntries[existingIndex].id)] = true

            const appendedEntries = []

            for (let entryIndex = 0; entryIndex < parsedEntries.length; entryIndex++) {
                const entry = parsedEntries[entryIndex]
                const entryId = String(entry.id)

                if (existingIds[entryId])
                    continue

                existingIds[entryId] = true
                appendedEntries.push(entry)
            }

            root.historyEntries = root.historyEntries.concat(appendedEntries)
            root.loadedOffset = request.offsetEnd

            if (appendedEntries.length === 0)
                root.consecutiveEmptyRanges += 1
            else
                root.consecutiveEmptyRanges = 0

            // Stop after several ranges without new entries to avoid an endless Show more loop.
            root.showMoreAvailable = root.baseMaxId > request.offsetEnd
                && root.consecutiveEmptyRanges < 3

            request.appendedCount = appendedEntries.length
            request.previousEntryCount = previousEntryCount

            // Append only the new rows. Existing delegates remain mounted.
            root.appendHistoryMoreEntries(appendedEntries)
        } else {
            root.historyEntries = parsedEntries
            root.loadedOffset = 0
            root.showMoreAvailable = false
            root.baseMaxId = 0
            root.consecutiveEmptyRanges = 0
            root.rebuildDisplayModel()
        }

        Qt.callLater(function() {
            if (
                request.id !== root.latestRequestId
                || root.commandMode
                || root.showActions
                || appList.count === 0
            ) {
                return
            }

            if (request.mode !== "history-more") {
                appList.currentIndex = 0
                appList.positionViewAtIndex(0, ListView.Beginning)
            } else if ((request.appendedCount || 0) > 0) {
                const firstNewIndex = request.previousEntryCount
                root.scrollToIndexSmooth(firstNewIndex)
            } else if (appList.currentIndex >= 0 && appList.currentIndex < appList.count) {
                appList.positionViewAtIndex(appList.currentIndex, ListView.Contain)
            }
        })
    }

    function parseImageIndex(output) {
        if (!root.activeRequest)
            return

        // Merge the index produced by the active helper process even if a newer request is queued.
        const nextPaths = Object.assign({}, root.imagePaths)
        const lines = output.split(/\r?\n/)
        const linePattern = /^id\s+(\d+)\s+"(.*)"$/

        for (let index = 0; index < lines.length; index++) {
            const match = linePattern.exec(lines[index].trim())

            if (!match)
                continue

            const entryId = String(match[1])
            const imagePath = String(match[2]).replace(/\\(["\\])/g, "$1")

            if (imagePath.length > 0)
                nextPaths[entryId] = imagePath
        }

        root.imagePaths = nextPaths
    }

    function finishListRequest() {
        if (root.activeRequest && root.activeRequest.mode === "history-more")
            root.isLoadingMore = false

        root.activeRequest = null

        if (root.hasQueuedRequest && root.queuedRequest) {
            const nextRequest = root.queuedRequest
            root.queuedRequest = null
            root.hasQueuedRequest = false
            root.startListRequest(nextRequest)
        }
    }

    function moveSelection(direction) {
        if (root.showActions) {
            const count = root.actionEntries.length

            if (count <= 0)
                return

            root.actionIndex = (root.actionIndex + direction + count) % count
            return
        }

        if (appList.count <= 0)
            return

        if (appList.currentIndex < 0) {
            appList.currentIndex = direction > 0 ? 0 : appList.count - 1
        } else {
            appList.currentIndex =
                (appList.currentIndex + direction + appList.count) % appList.count
        }

        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain)
    }

    function launchSelected() {
        if (root.showActions) {
            root.runSelectedAction()
            return
        }

        if (appList.count <= 0)
            return

        const selectedIndex = appList.currentIndex >= 0
            ? appList.currentIndex
            : 0

        const entry = root.displayEntryAt(selectedIndex)

        if (entry)
            root.activateEntry(entry)
    }

    function activateEntry(entry) {
        if (!entry)
            return

        if (entry.kind === "show-more") {
            root.loadMore()
            return
        }

        if (entry.kind === "command") {
            root.runCommand(entry)
            return
        }

        root.activeEntry = entry
        root.actionIndex = 0
        root.actionReturnText = search.text
        root.showActions = true
        search.text = ""
        Qt.callLater(function() {
            root.focusSearch()
        })
    }

    function runSelectedAction() {
        if (
            !root.activeEntry
            || root.actionIndex < 0
            || root.actionIndex >= root.actionEntries.length
        ) {
            return
        }

        const action = root.actionEntries[root.actionIndex]
        root.runEntryAction(action, root.activeEntry)
    }

    function runEntryAction(action, entry) {
        if (!action || !entry)
            return

        if (action.action === "sel") {
            if (root.runHelper(["sel", String(entry.id)], "sel", false))
                root.hide()
            return
        }

        if (action.action === "del") {
            root.runHelper(["del", String(entry.id)], "del", false)
            return
        }

        root.runHelper(
            [action.action, String(entry.id)],
            action.action,
            true
        )
    }

    function runCommand(entry) {
        if (!entry)
            return

        if (entry.action === "delete-range") {
            root.runHelper(
                ["del", "range", String(entry.count)],
                "delete-range",
                true
            )
        }
    }

    function runHelper(args, actionName, closeAfter) {
        if (actionProcess.running) {
            console.warn("Clipboard action is already running:", root.pendingAction)
            return false
        }

        root.pendingAction = actionName
        root.closeAfterAction = closeAfter
        actionProcess.command = ["bash", root.helperPath].concat(args)
        actionProcess.running = true
        return true
    }

    function entryIconSource(entry) {
        if (!entry)
            return root.missingIconSource

        if (entry.kind === "command")
            return entry.icon || root.missingIconSource

        if (entry.kind === "show-more")
            return entry.icon || root.missingIconSource

        if (entry.isImage) {
            const imagePath = root.imagePaths[String(entry.id)]

            if (imagePath)
                return "file://" + imagePath

            return root.missingIconSource
        }

        return Qt.resolvedUrl("../../Icon/clipboard-pen.svg")
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
            if (root.showActions) {
                root.showActions = false
                root.activeEntry = null
                root.actionIndex = 0
                search.text = root.actionReturnText
                root.actionReturnText = ""
                root.focusSearch()
            } else {
                root.hide()
            }
        }
    }

    ListModel {
        id: displayModel
    }

    NumberAnimation {
        id: listScrollAnimation
        target: appList
        property: "contentY"
        duration: 240
        easing.type: Easing.OutCubic
    }

    Process {
        id: listProcess
        command: []

        stdout: StdioCollector {
            onStreamFinished: root.parseListOutput(this.text)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const errorText = this.text.trim()

                if (errorText.length > 0)
                    console.error("Clipboard list error:", errorText)
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.error(
                    "Failed to read clipboard history:",
                    exitCode,
                    exitStatus
                )
                root.finishListRequest()
                return
            }

            indexProcess.command = [
                "bash",
                "-c",
                "cat \"${XDG_CACHE_HOME:-$HOME/.cache}/clipboard-data/clipboard-img\" 2>/dev/null || true"
            ]
            indexProcess.running = true
        }
    }

    Process {
        id: indexProcess
        command: []

        stdout: StdioCollector {
            onStreamFinished: root.parseImageIndex(this.text)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const errorText = this.text.trim()

                if (errorText.length > 0)
                    console.warn("Clipboard image index warning:", errorText)
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                console.warn("Failed to read clipboard image index:", exitCode, exitStatus)

            root.finishListRequest()
        }
    }

    Process {
        id: actionProcess
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                const outputText = this.text.trim()

                if (outputText.length > 0)
                    console.info("Clipboard action:", outputText)
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const errorText = this.text.trim()

                if (errorText.length > 0)
                    console.error("Clipboard action error:", root.pendingAction, errorText)
            }
        }

        onExited: function(exitCode, exitStatus) {
            const completedAction = root.pendingAction

            if (exitCode !== 0) {
                console.error(
                    "Clipboard action failed:",
                    completedAction,
                    exitCode,
                    exitStatus
                )
            } else if (completedAction === "del") {
                root.showActions = false
                root.activeEntry = null
                root.actionIndex = 0
                root.actionReturnText = ""
                root.lastInputMode = "history"

                root.suppressSearchChanges = true
                search.text = ""
                root.suppressSearchChanges = false

                root.historyEntries = []
                root.imagePaths = ({})
                root.loadedOffset = 0
                root.showMoreAvailable = false
                root.baseMaxId = 0
                root.consecutiveEmptyRanges = 0
                displayModel.clear()

                root.requestInitialHistory()
                Qt.callLater(function() {
                    root.focusSearch()
                })
            } else {
                if (root.closeAfterAction)
                    root.hide()

                refreshTimer.restart()
            }

            root.closeAfterAction = false
            root.pendingAction = ""
        }
    }

    Timer {
        id: searchTimer
        interval: 500
        repeat: false
        onTriggered: root.runSearch()
    }

    Timer {
        id: refreshTimer
        interval: 180
        repeat: false
        onTriggered: {
            root.historyEntries = []
            root.imagePaths = ({})
            displayModel.clear()
            root.requestInitialHistory()
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

            placeholderText: root.showActions
                ? "Choose an action..."
                : root.commandMode
                    ? "Search clipboard commands..."
                    : root.pinMode
                        ? "Pinned clipboard entries..."
                        : "Search clipboard history..."

            color: "#FFFFFF"
            placeholderTextColor: "#888888"

            font.pixelSize: 16

            selectByMouse: true
            readOnly: root.showActions

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
                if (root.suppressSearchChanges || root.showActions)
                    return

                root.invalidatePendingRequests()

                const nextMode = search.text.trim().startsWith(">")
                    ? "command"
                    : root.currentInputMode()

                if (nextMode === "command") {
                    searchTimer.stop()
                    root.showMoreAvailable = false
                    root.rebuildDisplayModel()
                } else {
                    if (
                        nextMode !== root.lastInputMode
                        || nextMode === "pin"
                        || nextMode === "history"
                    ) {
                        displayModel.clear()
                    } else {
                        root.removeTrailingShowMoreEntry()
                    }

                    searchTimer.restart()
                }

                root.lastInputMode = nextMode

                Qt.callLater(function() {
                    if (appList.count > 0) {
                        appList.currentIndex = 0
                        appList.positionViewAtIndex(0, ListView.Beginning)
                    } else {
                        appList.currentIndex = -1
                    }
                })
            }

            Keys.priority: Keys.BeforeItem

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

            height: root.showActions
                ? 3 * 58 + 2 * 6 + 56
                : appList.count === 0
                    ? 42
                    : Math.min(appList.count, 6) * 58
                      + (Math.min(appList.count, 6) - 1) * appList.spacing

            Behavior on height {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            ListView {
                id: appList

                anchors.fill: parent

                model: displayModel

                spacing: 6
                clip: true

                visible: !root.showActions && count > 0

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
                    } else if (currentIndex < 0 || currentIndex >= count) {
                        currentIndex = 0
                    }
                }

                delegate: Rectangle {
                    id: appDelegate

                    required property string payload
                    required property string entryKind
                    required property int index

                    property var entryData: JSON.parse(payload)

                    onPayloadChanged: {
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
                            property url requestedSource: root.entryIconSource(appDelegate.entryData)

                            onRequestedSourceChanged: {
                                fallbackActive = false
                            }

                            width: 34
                            height: 34

                            anchors.verticalCenter: parent.verticalCenter

                            source: fallbackActive
                                ? root.missingIconSource
                                : requestedSource

                            sourceSize.width: 34
                            sourceSize.height: 34

                            fillMode: Image.PreserveAspectFit

                            asynchronous: true
                            cache: true

                            onStatusChanged: {
                                if (status === Image.Error && !fallbackActive)
                                    fallbackActive = true
                            }
                        }

                        Column {
                            width: parent.width - appIcon.width - 12

                            anchors.verticalCenter: parent.verticalCenter

                            spacing: 3

                            Text {
                                width: parent.width

                                text: appDelegate.entryData.kind === "show-more" && root.isLoadingMore
                                    ? "Loading..."
                                    : appDelegate.entryData.name

                                color: "#FFFFFF"
                                font.pixelSize: 15

                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WrapAnywhere
                            }

                            Text {
                                width: parent.width

                                text: appDelegate.entryData.kind === "show-more" && root.isLoadingMore
                                    ? "Loading the next clipboard range..."
                                    : appDelegate.entryData.genericName
                                        || appDelegate.entryData.comment
                                        || appDelegate.entryData.id

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

                            if (
                                appDelegate.entryData.kind === "show-more"
                                && root.isLoadingMore
                            ) {
                                return
                            }

                            root.activateEntry(appDelegate.entryData)
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

            Column {
                id: actionsPanel

                anchors.fill: parent
                visible: root.showActions
                spacing: 6

                Repeater {
                    model: root.actionEntries

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: actionsPanel.width
                        height: 58

                        radius: 12

                        color: root.actionIndex === index
                            ? "#3A3A3A"
                            : actionMouse.containsMouse
                                ? "#292929"
                                : "transparent"

                        border.width: 1
                        border.color: root.actionIndex === index
                            ? "#7188F8"
                            : "#555555"

                        Row {
                            anchors.fill: parent

                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            spacing: 12

                            Image {
                                width: 34
                                height: 34

                                anchors.verticalCenter: parent.verticalCenter

                                source: modelData.icon
                                sourceSize.width: 34
                                sourceSize.height: 34

                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            Column {
                                width: parent.width - 46

                                anchors.verticalCenter: parent.verticalCenter

                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    color: "#FFFFFF"
                                    font.pixelSize: 15
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.genericName
                                    color: "#999999"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: actionMouse

                            anchors.fill: parent

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: root.actionIndex = index
                            onClicked: {
                                root.actionIndex = index
                                root.runEntryAction(modelData, root.activeEntry)
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    height: 50

                    text: root.activeEntry
                        ? "Selected: " + (root.activeEntry.isImage
                            ? "Image · ID " + root.activeEntry.id
                            : root.activeEntry.preview)
                        : "No clipboard item selected"

                    color: "#999999"
                    font.pixelSize: 12

                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                anchors.fill: parent

                visible: !root.showActions && appList.count === 0

                text: root.commandMode
                    ? (
                        root.searchQuery.length > 0
                            ? "No commands found"
                            : "No commands available"
                    )
                    : root.pinMode
                        ? "No pinned clipboard entries"
                        : search.text.trim().length > 0
                            ? "No clipboard entries found"
                            : "Clipboard history is empty"

                color: "#909090"
                font.pixelSize: 14

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
