import QtQuick
import "logic.js" as L

// A strip of minute marks that slides under a fixed line; the line sits on `minutes`.
Item {
    id: tape

    property real minutes: 0
    property bool interactive: false
    property int minMinutes: 1
    property int maxMinutes: 180
    readonly property int pxPerMinute: 64
    signal picked(int minutes)

    implicitWidth: 640
    implicitHeight: 56
    clip: true

    Repeater {
        // Only the minutes in view are built.
        model: Math.ceil(tape.width / tape.pxPerMinute) + 3
        delegate: Item {
            required property int index
            readonly property int minute: Math.floor(tape.minutes - tape.width / 2 / tape.pxPerMinute) + index - 1
            visible: minute >= 0
            x: tape.width / 2 + (minute - tape.minutes) * tape.pxPerMinute
            width: tape.pxPerMinute
            height: tape.height

            Rectangle { width: 2; height: 24; radius: 1; x: -1; color: "#8a929c" }
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    x: (index + 1) * tape.pxPerMinute / 4
                    width: 1
                    height: 12
                    color: "#3a3a3a"
                }
            }
            Text {
                x: -width / 2
                y: 30
                text: parent.minute
                color: "#9aa3ad"
                font.pixelSize: 11
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }
    }

    // Fade the ends into the black panel.
    Rectangle {
        width: tape.width * 0.2
        height: tape.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#000000" }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        anchors.right: parent.right
        width: tape.width * 0.2
        height: tape.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: "#000000" }
        }
    }

    Rectangle {
        x: tape.width / 2 - 1
        y: -2
        width: 2
        height: 30
        radius: 1
        color: palette.accent
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: tape.interactive
        cursorShape: enabled ? Qt.SizeHorCursor : Qt.ArrowCursor
        property real startX: 0
        property real startMinutes: 0
        property int wheelAccum: 0

        function clamp(m) {
            return Math.max(tape.minMinutes, Math.min(tape.maxMinutes, Math.round(m)))
        }
        onPressed: mouse => {
            startX = mouse.x
            startMinutes = tape.minutes
        }
        onPositionChanged: mouse => tape.picked(clamp(startMinutes - (mouse.x - startX) / tape.pxPerMinute))
        onWheel: wheel => {
            // Horizontal swipes move the tape like dragging it; vertical scroll up adds time.
            const delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? -wheel.angleDelta.x : wheel.angleDelta.y
            const r = L.wheelSteps(wheelAccum, delta)
            wheelAccum = r.accum
            if (r.steps !== 0)
                tape.picked(clamp(tape.minutes + r.steps))
        }
    }
}
