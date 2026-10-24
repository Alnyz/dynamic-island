import QtQuick
import "logic.js" as L

Column {
    id: up

    property var calendar: null
    property var events: []
    property bool showJoin: true
    signal linkRequested(string url)

    function load() { events = calendar ? calendar.upNext(2) : [] }

    onCalendarChanged: load()
    Connections {
        target: up.calendar
        function onChanged() { up.load() }
    }
    // Drop events as they end while the panel stays open.
    Timer { interval: 60000; repeat: true; running: up.visible; onTriggered: up.load() }

    spacing: 10

    Text {
        text: "UP NEXT"
        color: "#9aa3ad"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
    }

    Repeater {
        model: up.events
        delegate: Row {
            required property var modelData
            width: up.width
            spacing: 10
            Text {
                width: 48
                text: L.eventWhen(modelData)
                color: "#9aa3ad"
                font.pixelSize: 12
                font.features: { "tnum": 1 }
                topPadding: 1
            }
            Column {
                width: parent.width - 58 - (join.visible ? join.width + 10 : 0)
                spacing: 2
                Text {
                    width: parent.width
                    text: modelData.title
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: L.eventDetail(modelData, new Date())
                    color: "#9aa3ad"
                    font.pixelSize: 12
                }
            }
            Pill {
                id: join
                visible: up.showJoin && !!modelData.link
                height: 26
                primary: true
                text: "Join"
                onClicked: up.linkRequested(modelData.link)
            }
        }
    }

    Text {
        width: parent.width
        visible: up.events.length === 0
        wrapMode: Text.WordWrap
        color: "#9aa3ad"
        font.pixelSize: 12
        text: !up.calendar || !up.calendar.configured ? "Add your Google Calendar link to see events here"
            : !up.calendar.loaded ? "Loading events…"
            : !up.calendar.ok && up.calendar.lastSuccess.getTime() > 0
              ? "Couldn't reach Google Calendar · last updated " + Qt.formatTime(up.calendar.lastSuccess, "HH:mm")
            : !up.calendar.ok ? "Couldn't reach Google Calendar"
            : "Nothing else today or tomorrow"
    }
}
