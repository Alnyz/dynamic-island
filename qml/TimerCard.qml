import QtQuick
import "logic.js" as L

Column {
    id: card

    property var timer
    readonly property bool active: timer.running || timer.paused
    readonly property real leftMs: timer.paused ? timer.pausedRemainingMs : timer.remainingMs

    spacing: 8

    Text {
        text: "TIMER"
        color: "#9aa3ad"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
    }

    Text {
        text: card.active ? L.countdownText(card.leftMs) : "0:00"
        color: card.active ? "#ffffff" : "#8a929c"
        font.pixelSize: 40
        font.weight: Font.ExtraLight
        font.letterSpacing: -1
        font.features: { "tnum": 1 }
    }

    Rectangle {
        visible: card.active
        width: parent.width
        height: 3
        radius: 1.5
        color: "#262626"
        Rectangle {
            width: card.timer.durationMs > 0 ? parent.width * card.leftMs / card.timer.durationMs : 0
            height: parent.height
            radius: parent.radius
            color: palette.accent
        }
    }

    Text {
        visible: card.active
        text: card.timer.paused ? "Paused" : "Ends at " + Qt.formatTime(new Date(card.timer.endMs), "HH:mm")
        color: "#9aa3ad"
        font.pixelSize: 12
    }

    Flow {
        width: parent.width
        spacing: 6
        topPadding: 4
        Repeater {
            model: card.active ? [] : [5, 15, 25, 60]
            delegate: Pill {
                required property int modelData
                height: 30
                text: modelData + " min"
                onClicked: card.timer.start(modelData)
            }
        }
        Pill {
            visible: card.active
            height: 30
            iconName: card.timer.running ? "media-playback-pause" : "media-playback-start"
            toolTip: card.timer.running ? "Pause" : "Resume"
            onClicked: card.timer.running ? card.timer.pause() : card.timer.resume()
        }
        Pill {
            visible: card.active
            height: 30
            text: "+1 min"
            onClicked: card.timer.addMinutes(1)
        }
        Pill {
            visible: card.active
            height: 30
            iconName: "edit-undo"
            toolTip: "Reset"
            onClicked: card.timer.reset()
        }
    }
}
