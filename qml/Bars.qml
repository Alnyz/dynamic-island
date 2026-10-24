import QtQuick

Row {
    id: bars

    property bool running: false
    property color color: "#e8e2d0"

    spacing: 2
    height: 14

    Repeater {
        model: 4
        Rectangle {
            id: bar
            required property int index
            width: 3
            radius: 1
            color: bars.color
            anchors.bottom: parent.bottom
            height: 3

            SequentialAnimation on height {
                running: bars.running
                loops: Animation.Infinite
                PauseAnimation { duration: [0, 300, 150, 450][bar.index] }
                NumberAnimation { to: 14; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 4; duration: 500; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) bar.height = 3
            }
        }
    }
}
