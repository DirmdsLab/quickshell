import QtQuick

Item {
    id: root

    required property Item launcher

    width: 80
    height: 40

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
        anchors.fill: parent

        radius: 12

        color: launcher.open
               ? "#803030"
               : "#303030"

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        Text {
            anchors.centerIn: parent

            text: launcher.open
                  ? "CLOSE"
                  : "OPEN"

            color: "white"

            font.pixelSize: 13
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                launcher.toggle()
            }
        }
    }
}