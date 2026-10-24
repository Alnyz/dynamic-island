import QtQuick
import "logic.js" as L

Column {
    id: cal

    readonly property color accent: palette.accent
    property var calendar: null
    property int year: new Date().getFullYear()
    property int month0: new Date().getMonth()
    readonly property var cells: L.monthGrid(year, month0)
    property var eventDays: ({})

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July",
                                       "August", "September", "October", "November", "December"]

    function key(y, m, d) { return y + "-" + m + "-" + d }

    function shift(delta) {
        const d = new Date(year, month0 + delta, 1)
        year = d.getFullYear()
        month0 = d.getMonth()
    }

    function loadDots() {
        const days = {}
        if (calendar) {
            const first = cells[0]
            const last = cells[cells.length - 1]
            for (const ev of calendar.occurrences(new Date(first.y, first.m, first.d), new Date(last.y, last.m, last.d))) {
                const s = new Date(ev.start)
                days[key(s.getFullYear(), s.getMonth(), s.getDate())] = true
            }
        }
        eventDays = days
    }

    onCellsChanged: loadDots()
    onCalendarChanged: loadDots()
    Connections {
        target: cal.calendar
        function onChanged() { cal.loadDots() }
    }

    spacing: 8

    Item {
        width: parent.width
        height: 26
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: cal.monthNames[cal.month0] + " " + cal.year
            color: "#ffffff"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Row {
            anchors.right: parent.right
            spacing: 2
            ControlButton { iconName: "go-previous"; iconSize: 12; onClicked: cal.shift(-1) }
            ControlButton { iconName: "go-next"; iconSize: 12; onClicked: cal.shift(1) }
        }
    }

    Grid {
        columns: 7
        // A 6-week month packs tighter so it takes no more room than a 5-week one.
        readonly property bool sixWeeks: cal.cells.length > 35
        rowSpacing: sixWeeks ? 0 : 4
        readonly property real cellW: cal.width / 7

        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]
            delegate: Text {
                required property string modelData
                width: parent.cellW
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: "#8a929c"
                font.pixelSize: 10
            }
        }

        Repeater {
            model: cal.cells
            delegate: Item {
                required property var modelData
                readonly property var today: new Date()
                readonly property bool isToday: modelData.y === today.getFullYear() && modelData.m === today.getMonth() && modelData.d === today.getDate()
                width: parent.cellW
                height: parent.sixWeeks ? 23 : 24

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: cal.accent
                    visible: isToday
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.d
                    color: isToday ? "#ffffff" : modelData.inMonth ? "#ffffff" : "#8a929c"
                    font.pixelSize: 12
                    font.weight: isToday ? Font.Bold : Font.Normal
                }
                Rectangle {
                    visible: !isToday && cal.eventDays[cal.key(modelData.y, modelData.m, modelData.d)] === true
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 3
                    height: 3
                    radius: 1.5
                    color: cal.accent
                }
            }
        }
    }
}
