import QtQuick
import "logic.js" as L

Item {
    id: tab

    property var timer
    property int setMinutes: 25
    readonly property bool active: timer.running || timer.paused
    readonly property real leftMs: timer.paused ? timer.pausedRemainingMs : timer.remainingMs
    readonly property string clock: active ? L.countdownText(leftMs) : setMinutes + ":00"

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        spacing: 0

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property int split: tab.clock.lastIndexOf(":")
            Text {
                text: tab.clock.slice(0, parent.split)
                color: "#ffffff"
                font.pixelSize: 84
                font.weight: Font.ExtraLight
                font.letterSpacing: -2
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.baseline: parent.children[0].baseline
                text: tab.clock.slice(parent.split)
                color: "#9aa3ad"
                font.pixelSize: 40
                font.weight: Font.Light
                font.features: { "tnum": 1 }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !tab.active ? "Drag the tape or scroll to set"
                : tab.timer.paused ? "Paused"
                : "Ends at " + Qt.formatTime(new Date(tab.timer.endMs), "HH:mm")
            color: "#9aa3ad"
            font.pixelSize: 12
        }

        Item { width: 1; height: 22 }

        Tape {
            objectName: "tape"
            anchors.horizontalCenter: parent.horizontalCenter
            width: 640
            height: 56
            minutes: tab.active ? tab.leftMs / 60000 : tab.setMinutes
            interactive: !tab.active
            onPicked: m => tab.setMinutes = m
        }

        Item { width: 1; height: 18 }

        Row {
            visible: !tab.active
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: [1, 3, 5, 10, 15, 25, 45, 60]
                delegate: Pill {
                    required property int modelData
                    required property int index
                    objectName: "preset-" + modelData
                    height: 30
                    text: index === 7 ? modelData + " min" : String(modelData)
                    selected: tab.setMinutes === modelData
                    onClicked: tab.setMinutes = modelData
                }
            }
            Item { width: 4; height: 1 }
            Pill {
                objectName: "timerStart"
                text: "Start"
                primary: true
                onClicked: tab.timer.start(tab.setMinutes)
            }
        }

        Row {
            visible: tab.active
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Pill {
                objectName: "timerReset"
                iconName: "edit-undo"
                toolTip: "Reset"
                onClicked: tab.timer.reset()
            }
            Pill {
                objectName: "timerToggle"
                primary: true
                iconName: tab.timer.running ? "media-playback-pause" : "media-playback-start"
                text: tab.timer.running ? "Pause" : "Resume"
                onClicked: tab.timer.running ? tab.timer.pause() : tab.timer.resume()
            }
            Pill {
                objectName: "timerAdd1"
                text: "+1 min"
                onClicked: tab.timer.addMinutes(1)
            }
            Pill {
                objectName: "timerAdd5"
                text: "+5 min"
                onClicked: tab.timer.addMinutes(5)
            }
        }
    }
}
