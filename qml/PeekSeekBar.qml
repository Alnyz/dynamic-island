import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15

// A thin seek bar along the bottom of the music peek; drag or click to jump.
Item {
    id: peekSeek
    objectName: "peekSeek"
    property var island: null
    // While dragging, the bar follows the pointer; the player seeks on release.
    property real dragFraction: -1
    readonly property real fraction: dragFraction >= 0 ? dragFraction
        : island.player && island.player.length > 0 ? Math.max(0, Math.min(1, island.livePosition / island.player.length)) : 0

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: seekArea.containsMouse || seekArea.pressed ? 4 : 2
        radius: height / 2
        color: Qt.rgba(ipal.windowText.r, ipal.windowText.g, ipal.windowText.b, 0.18)
        Behavior on height { NumberAnimation { duration: 120 } }
        Rectangle {
            objectName: "peekSeekFill"
            width: parent.width * peekSeek.fraction
            height: parent.height
            radius: parent.radius
            color: island.coverTinted ? island.coverTint : ipal.windowText
        }
    }
    Rectangle {
        visible: seekArea.containsMouse || seekArea.pressed
        width: 9
        height: 9
        radius: 4.5
        x: peekSeek.fraction * peekSeek.width - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: ipal.windowText
    }
    MouseArea {
        id: seekArea
        objectName: "peekSeekArea"
        anchors.fill: parent
        anchors.topMargin: -3
        hoverEnabled: true
        enabled: island.player !== null && island.player.canSeek !== false
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function fractionAt(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: mouse => peekSeek.dragFraction = fractionAt(mouse.x)
        onPositionChanged: mouse => { if (pressed) peekSeek.dragFraction = fractionAt(mouse.x) }
        onReleased: mouse => {
            const to = Math.round(fractionAt(mouse.x) * island.player.length)
            island.player.position = to
            if (island.songClock)
                island.songClock.moveTo(to)
            peekSeek.dragFraction = -1
        }
        onCanceled: peekSeek.dragFraction = -1
    }
}
