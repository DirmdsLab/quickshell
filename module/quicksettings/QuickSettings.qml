import QtQuick
import QtQuick.Controls

Item {
    id: root

    property bool open: false
    property real offsetScale: root.open ? 0 : 1

    property real brightness: 72
    property real volume: 46

    property bool internetEnabled: true
    property bool bluetoothEnabled: false
    property bool hotspotEnabled: false
    property bool airplaneModeEnabled: false

    property var audioDevices: [
        "Built-in speakers",
        "Headphones",
        "HDMI output"
    ]
    property int audioDeviceIndex: 0

    property var tileEntries: [
        { id: "internet", label: "Internet", icon: "◉" },
        { id: "bluetooth", label: "Bluetooth", icon: "ᛒ" },
        { id: "hotspot", label: "Hotspot", icon: "⌁" },
        { id: "airplane", label: "Airplane mode", icon: "AP" }
    ]


    width: parent
        ? Math.min(600, Math.max(280, parent.width - 32))
        : 600

    // Match the launcher's typical height with six visible results.
    height: parent
        ? Math.min(parent.height - 32, 476)
        : 476


    anchors.right: parent.right
    anchors.bottom: parent.bottom
    // Extend slightly beyond the screen edge to prevent a hairline gap from antialiasing.
    anchors.rightMargin: -2
    anchors.bottomMargin: -2 - (height + 12) * root.offsetScale

    visible: root.open || root.offsetScale < 1
    opacity: 1 - root.offsetScale
    focus: root.open

    function toggle() {
        if (root.open)
            root.hide()
        else
            root.show()
    }

    function show() {
        root.open = true
        root.forceActiveFocus()
    }

    function hide() {
        root.open = false
    }

    function focusPanel() {
        if (root.open)
            root.forceActiveFocus()
    }

    function tileEnabled(tileId) {
        switch (tileId) {
        case "internet":
            return root.internetEnabled
        case "bluetooth":
            return root.bluetoothEnabled
        case "hotspot":
            return root.hotspotEnabled
        case "airplane":
            return root.airplaneModeEnabled
        default:
            return false
        }
    }

    function toggleTile(tileId) {
        switch (tileId) {
        case "internet":
            root.internetEnabled = !root.internetEnabled
            break
        case "bluetooth":
            root.bluetoothEnabled = !root.bluetoothEnabled
            break
        case "hotspot":
            root.hotspotEnabled = !root.hotspotEnabled
            break
        case "airplane":
            root.airplaneModeEnabled = !root.airplaneModeEnabled
            break
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.hide()
    }

    Behavior on offsetScale {
        NumberAnimation {
            duration: root.open ? 600 : 480
            easing.type: Easing.InOutCubic
        }
    }

    Item {
        id: panel
        anchors.fill: parent

        Canvas {
            id: panelBackground


            x: -root.x
            y: -root.y
            width: root.parent ? root.parent.width : root.width
            height: root.parent ? root.parent.height : root.height

            onXChanged: requestPaint()
            onYChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            antialiasing: true

            onPaint: {
                const context = getContext("2d")
                const screenWidth = width
                const screenHeight = height
                const left = root.x
                const top = root.y
                const radius = 28
            
                context.clearRect(0, 0, screenWidth, screenHeight)
            
                // Fill the panel while keeping the screen edges connected.
                context.beginPath()
                context.moveTo(0, screenHeight)
            
                // 8 o'clock: modest outward curve.
                context.lineTo(left - radius, screenHeight)
                context.quadraticCurveTo(
                    left,
                    screenHeight,
                    left,
                    screenHeight - radius
                )
            
                // Left edge and 11 o'clock normal rounded corner.
                context.lineTo(left, top + radius)
                context.quadraticCurveTo(
                    left,
                    top,
                    left + radius,
                    top
                )
            
                // Top edge and 1 o'clock outward curve.
                context.lineTo(screenWidth - radius, top)
                context.quadraticCurveTo(
                    screenWidth,
                    top,
                    screenWidth,
                    top - radius
                )
            
                // Connect directly to the screen edges.
                context.lineTo(screenWidth, 0)
                context.lineTo(screenWidth, screenHeight)
                context.closePath()
            
                context.fillStyle = "#171d1d"
                context.fill()
            
                // Draw only the visible panel contour.
                context.beginPath()
                context.moveTo(left - radius, screenHeight)
                context.quadraticCurveTo(
                    left,
                    screenHeight,
                    left,
                    screenHeight - radius
                )
            
                context.lineTo(left, top + radius)
                context.quadraticCurveTo(
                    left,
                    top,
                    left + radius,
                    top
                )
            
                context.lineTo(screenWidth - radius, top)
                context.quadraticCurveTo(
                    screenWidth,
                    top,
                    screenWidth,
                    top - radius
                )
            
                context.strokeStyle = "#2d3838"
                context.lineWidth = 1
                context.stroke()
            }

        }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 18
            spacing: 6

            Row {
                width: parent.width
                height: 24
                spacing: 8

                Text {
                    id: titleText
                    text: "Quick settings"
                    color: "#e8f0f0"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: Math.max(0, parent.width - titleText.implicitWidth - previewBadge.width - 16)
                    height: 1
                }

                Rectangle {
                    id: previewBadge
                    width: 64
                    height: 20
                    radius: 10
                    color: "#273333"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "PREVIEW"
                        color: "#9eeaf3"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }

            Item {
                width: parent.width
                height: 32

                Row {
                    id: brightnessLabel
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 12

                    Text {
                        text: "☼  Brightness"
                        color: "#c8d3d3"
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.right: parent.right
                        text: Math.round(root.brightness) + "%"
                        color: "#9eeaf3"
                        font.pixelSize: 10
                    }
                }

                Slider {
                    id: brightnessSlider
                    x: 0
                    y: 12
                    width: parent.width
                    height: 20
                    from: 0
                    to: 100
                    value: root.brightness
                    leftPadding: 7
                    rightPadding: 7
                    topPadding: 0
                    bottomPadding: 0
                    onMoved: root.brightness = value

                    background: Rectangle {
                        x: brightnessSlider.leftPadding
                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                        width: brightnessSlider.availableWidth
                        height: 5
                        radius: 3
                        color: "#354040"

                        Rectangle {
                            width: parent.width * brightnessSlider.position
                            height: parent.height
                            radius: parent.radius
                            color: "#9eeaf3"
                        }
                    }

                    handle: Rectangle {
                        width: 13
                        height: 13
                        radius: 7
                        x: brightnessSlider.leftPadding
                            + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                        y: brightnessSlider.topPadding
                            + brightnessSlider.availableHeight / 2 - height / 2
                        color: "#a5eff7"
                        border.width: 1
                        border.color: "#d8fbff"
                    }
                }
            }

            Item {
                width: parent.width
                height: 32

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 12

                    Text {
                        text: "♫  Volume"
                        color: "#c8d3d3"
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.right: parent.right
                        text: Math.round(root.volume) + "%"
                        color: "#9eeaf3"
                        font.pixelSize: 10
                    }
                }

                Slider {
                    id: volumeSlider
                    x: 0
                    y: 12
                    width: parent.width
                    height: 20
                    from: 0
                    to: 100
                    value: root.volume
                    leftPadding: 7
                    rightPadding: 7
                    topPadding: 0
                    bottomPadding: 0
                    onMoved: root.volume = value

                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: volumeSlider.availableWidth
                        height: 5
                        radius: 3
                        color: "#354040"

                        Rectangle {
                            width: parent.width * volumeSlider.position
                            height: parent.height
                            radius: parent.radius
                            color: "#9eeaf3"
                        }
                    }

                    handle: Rectangle {
                        width: 13
                        height: 13
                        radius: 7
                        x: volumeSlider.leftPadding
                            + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding
                            + volumeSlider.availableHeight / 2 - height / 2
                        color: "#a5eff7"
                        border.width: 1
                        border.color: "#d8fbff"
                    }
                }
            }

            Grid {
                id: tileGrid
                width: parent.width
                height: 88
                columns: 2
                rowSpacing: 6
                columnSpacing: 8

                Repeater {
                    model: root.tileEntries

                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index

                        property bool active: root.tileEnabled(modelData.id)

                        width: (tileGrid.width - tileGrid.columnSpacing) / 2
                        height: 41
                        radius: 14
                        color: active ? "#9eeaf3" : "#2a3232"
                        border.width: active ? 0 : 1
                        border.color: "#364141"

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 8
                            spacing: 8

                            Rectangle {
                                width: 25
                                height: 25
                                radius: 13
                                anchors.verticalCenter: parent.verticalCenter
                                color: tile.active ? "#7edce8" : "#3b4646"

                                Text {
                                    anchors.centerIn: parent
                                    text: tile.modelData.icon
                                    color: tile.active ? "#0d292d" : "#e0e9e9"
                                    font.pixelSize: tile.modelData.icon === "AP" ? 9 : 15
                                    font.weight: Font.DemiBold
                                }
                            }

                            Column {
                                width: parent.width - 42
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: tile.modelData.label
                                    color: tile.active ? "#0c292d" : "#e1e9e9"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: tile.active ? "On" : "Off"
                                    color: tile.active ? "#24565c" : "#9eabab"
                                    font.pixelSize: 9
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleTile(tile.modelData.id)
                        }
                    }
                }
            }

            Rectangle {
                id: audioDeviceRow
                width: parent.width
                height: 36
                radius: 13
                color: audioMouse.containsMouse ? "#303b3b" : "#242d2d"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9

                    Text {
                        text: "♫"
                        color: "#9eeaf3"
                        font.pixelSize: 17
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - 60
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "Audio output"
                            color: "#e0e9e9"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            text: root.audioDevices[root.audioDeviceIndex]
                            color: "#aab8b8"
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: "›"
                        color: "#aab8b8"
                        font.pixelSize: 22
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: audioMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.audioDeviceIndex = (root.audioDeviceIndex + 1)
                            % root.audioDevices.length
                    }
                }
            }

        }
    }
}
