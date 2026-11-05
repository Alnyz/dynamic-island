import QtQuick
import org.kde.kirigami as Kirigami
import "logic.js" as L

// The right-click menu on the pill: L.pillMenu's rows, with the timer presets side by side.
Slide {
    property var island: null

    component MenuRow: Rectangle {
        id: row
        property string icon
        property string label
        signal picked()
        width: parent ? parent.width : 0
        height: 32
        radius: 10
        color: rowArea.containsMouse ? Qt.rgba(palette.windowText.r, palette.windowText.g, palette.windowText.b, 0.12) : "transparent"
        Kirigami.Icon {
            id: rowIcon
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: row.icon
            color: palette.windowText
            isMask: true
        }
        Text {
            anchors.left: rowIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: palette.windowText
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked()
        }
    }

    shown: island.mode === "menu"
    Column {
        objectName: "pillMenu"
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4
        Repeater {
            model: island.mode === "menu" ? island.menuRows : []
            delegate: Item {
                id: entry
                required property var modelData
                width: parent.width
                height: 32
                MenuRow {
                    visible: !entry.modelData.minutes
                    objectName: "menu-" + entry.modelData.key
                    icon: entry.modelData.icon
                    label: entry.modelData.label
                    onPicked: island.pickMenu(entry.modelData.key)
                }
                // Timer presets sit side by side on one row.
                Row {
                    visible: !!entry.modelData.minutes
                    anchors.fill: parent
                    spacing: 6
                    Kirigami.Icon {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: entry.modelData.icon
                        color: palette.windowText
                        isMask: true
                    }
                    Item { width: 4; height: 1 }
                    Repeater {
                        model: entry.modelData.minutes || []
                        delegate: Rectangle {
                            required property int modelData
                            objectName: "menu-timer-" + modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64
                            height: 26
                            radius: 13
                            color: chipArea.containsMouse ? Qt.rgba(palette.windowText.r, palette.windowText.g, palette.windowText.b, 0.22) : Qt.rgba(palette.windowText.r, palette.windowText.g, palette.windowText.b, 0.1)
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData + " min"
                                color: palette.windowText
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: island.pickMenu("timers", parent.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
