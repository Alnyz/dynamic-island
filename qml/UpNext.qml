import QtQuick
import "logic.js" as L

Column {
    id: up

    property var calendar: null
    property var events: []
    property bool showJoin: true
    // A day picked on the month calendar: its events instead of what's next. null for up next.
    property var day: null
    property var now: () => new Date()
    // A picked day shows this many events, then "+N more".
    property int dayLimit: 4
    signal linkRequested(string url)
    signal dayCleared()

    function load() {
        if (!calendar)
            events = []
        else if (day)
            events = calendar.occurrences(day, day)
        else
            events = calendar.upNext(2)
    }
    readonly property var shown: day ? events.slice(0, dayLimit) : events

    onCalendarChanged: load()
    onDayChanged: load()
    Connections {
        target: up.calendar
        function onChanged() { up.load() }
    }
    // Drop events as they end while the panel stays open.
    Timer { interval: 60000; repeat: true; running: up.visible; onTriggered: up.load() }

    spacing: 10

    Item {
        width: parent.width
        height: heading.implicitHeight
        Text {
            id: heading
            objectName: "upNextHeading"
            text: up.day ? L.dayName(up.day, up.now()).toUpperCase() : "UP NEXT"
            color: palette.placeholderText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }
        Text {
            objectName: "upNextBack"
            visible: up.day !== null
            anchors.right: parent.right
            text: "Upcoming"
            color: backArea.containsMouse ? palette.windowText : palette.accent
            font.pixelSize: 12
            MouseArea {
                id: backArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: up.dayCleared()
            }
        }
    }

    Repeater {
        model: up.shown
        delegate: Row {
            required property var modelData
            width: up.width
            spacing: 10
            Text {
                width: 48
                text: L.eventWhen(modelData)
                color: palette.placeholderText
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
                    color: palette.windowText
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: L.eventDetail(modelData, new Date(), up.day !== null)
                    color: palette.placeholderText
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
        objectName: "upNextMore"
        visible: up.day !== null && up.events.length > up.dayLimit
        text: "+" + (up.events.length - up.dayLimit) + " more"
        color: palette.placeholderText
        font.pixelSize: 12
    }

    Text {
        objectName: "upNextEmpty"
        width: parent.width
        visible: up.events.length === 0
        wrapMode: Text.WordWrap
        color: palette.placeholderText
        font.pixelSize: 12
        text: !up.calendar || !up.calendar.configured ? "Add your Google Calendar link to see events here"
            : !up.calendar.loaded ? "Loading events…"
            : !up.calendar.ok && up.calendar.lastSuccess.getTime() > 0
              ? "Couldn't reach Google Calendar · last updated " + Qt.formatTime(up.calendar.lastSuccess, "HH:mm")
            : !up.calendar.ok ? "Couldn't reach Google Calendar"
            : up.day ? "Nothing on this day"
            : "Nothing else today or tomorrow"
    }
}
