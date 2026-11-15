import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15
import "logic.js" as L

// A 0 to 1 slider that drags, clicks and scrolls in 5% steps.
Item {
    id: slider

    property real value: 0
    property bool dimmed: false
    property color fill: ipal.accent
    property color trackColor: ipal.button
    signal moved(real value)

    implicitHeight: 22

    function set(v) {
        slider.moved(Math.max(0, Math.min(1, v)))
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: slider.trackColor
        Rectangle {
            width: track.width * Math.max(0, Math.min(1, slider.value))
            height: parent.height
            radius: parent.radius
            color: slider.dimmed ? ipal.mid : slider.fill
        }
    }
    Rectangle {
        x: track.width * Math.max(0, Math.min(1, slider.value)) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        color: ipal.windowText
    }
    MouseArea {
        anchors.fill: parent
        anchors.leftMargin: -8
        anchors.rightMargin: -8
        property int wheelAccum: 0
        onPressed: mouse => slider.set((mouse.x - 8) / track.width)
        onPositionChanged: mouse => slider.set((mouse.x - 8) / track.width)
        onWheel: wheel => {
            const r = L.wheelSteps(wheelAccum, L.scrollAmount(wheel.angleDelta.y, wheel.inverted) || -wheel.angleDelta.x)
            wheelAccum = r.accum
            if (r.steps !== 0)
                slider.set(Math.round((slider.value + r.steps * 0.05) * 20) / 20)
        }
    }
}
