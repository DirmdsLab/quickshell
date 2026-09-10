import QtQuick
import QtQuick.Controls

Item {
    id: root

    // =========================================================
    // PUBLIC API
    // =========================================================

    property bool open: false

    function toggle() {
        root.open = !root.open

        if (root.open)
            search.forceActiveFocus()
    }

    function show() {
        root.open = true
        search.forceActiveFocus()
    }

    function hide() {
        root.open = false
    }

    // =========================================================
    // LAUNCHER SIZE
    // =========================================================

    width: 600

    implicitHeight: content.height + 40
    height: implicitHeight

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    // =========================================================
    // ANIMATION
    // =========================================================

    property real offsetScale:
        root.open ? 0 : 1

    visible: offsetScale < 1

    opacity: 1 - offsetScale

    anchors.bottomMargin:
        (-height - 10) * offsetScale

    Behavior on offsetScale {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    // =========================================================
    // BACKGROUND
    // =========================================================

    Rectangle {
        anchors.fill: parent

        radius: 24

        color: "#202020"

        border.width: 1
        border.color: "#404040"
    }

    // =========================================================
    // CONTENT
    // =========================================================

    Column {
        id: content

        width: parent.width

        spacing: 12

        padding: 20

        // =====================================================
        // SEARCH
        // =====================================================

        TextField {
            id: search

            width: parent.width - 40
            height: 50

            placeholderText: "Search applications..."

            color: "white"
            placeholderTextColor: "#888888"

            font.pixelSize: 16

            background: Rectangle {
                radius: 14

                color: "#303030"

                border.width: 1
                border.color: "#444444"
            }

            Keys.onEscapePressed: {
                root.hide()
            }
        }

        // =====================================================
        // APP LIST
        // =====================================================

        Column {
            id: appList

            width: parent.width - 40

            spacing: 6

            Repeater {
                model: [
                    "App 1",
                    "App 2",
                    "App 3",
                    "App 4"
                ]

                delegate: Rectangle {
                    width: appList.width
                    height: 52

                    radius: 12

                    color: mouseArea.containsMouse
                           ? "#3a3a3a"
                           : "#282828"

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16

                        anchors.verticalCenter:
                            parent.verticalCenter

                        text: modelData

                        color: "white"

                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: mouseArea

                        anchors.fill: parent

                        hoverEnabled: true

                        onClicked: {
                            console.log("Selected:", modelData)
                        }
                    }
                }
            }
        }
    }
}