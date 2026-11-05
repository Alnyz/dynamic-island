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

                NumberAnimation {
                    to: [14, 10, 13, 11][bar.index]
                    duration: [380, 520, 430, 490][bar.index]
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: [3, 4, 2, 3][bar.index]
                    duration: [380, 520, 430, 490][bar.index]
                    easing.type: Easing.InOutSine
                }

                onRunningChanged: if (!running) bar.height = 3
            }
        }
    }
}
