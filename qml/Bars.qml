import QtQuick
import "logic.js" as L

// The little level meter on the music pill. With a sound level (0..1) the bars follow it;
// without one (-1) they play a loop.
Row {
    id: bars

    property bool running: false
    property color color: palette.brightText
    // The output's peak level, or -1 when it isn't being measured.
    property real level: -1
    readonly property bool live: running && level >= 0
    property real phase: 0

    spacing: 2
    height: 14

    // Keeps the bars from moving in lockstep while following the level. Moved on with each new
    // level rather than by a timer of its own, so the bars redraw only when the sound is measured.
    // The level comes about every 40 ms; 0.23 a step keeps the old sway of 0.35 every 60 ms.
    onLevelChanged: if (live) phase += 0.23

    Repeater {
        model: 4
        Rectangle {
            id: bar
            required property int index
            objectName: "bar" + index
            width: 3
            radius: 1
            color: bars.color
            anchors.bottom: parent.bottom
            // Reads running so it settles back to 3 when the loop stops; an assignment would break the binding.
            height: bars.live ? L.barHeight(bars.level, bar.index, bars.phase) : (bars.running, 3)

            SequentialAnimation on height {
                running: bars.running && !bars.live
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
            }
        }
    }
}
