import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami
import "logic.js" as L

// Saved notifications as NotificationHistory.groups gives them, one card per app. Changes go out as signals.
Item {
    id: tab

    property var groups: []
    property real lastSeen: 0
    property var now: () => Date.now()
    readonly property int newCount: groups.reduce((n, g) => n + L.newCount(g.rows, lastSeen), 0)

    signal openRequested(string id, string desktopEntry)
    signal removeRequested(string id)
    signal clearRequested()

    Item {
        id: head
        visible: tab.groups.length > 0
        width: parent.width
        height: 26

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Text {
                anchors.baseline: parent.children[1].baseline
                text: "Notifications"
                color: "#ffffff"
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Text {
                objectName: "notifHeader"
                text: tab.newCount ? tab.newCount + " new" : "all seen"
                color: "#9aa3ad"
                font.pixelSize: 12
            }
        }
        Rectangle {
            objectName: "notifClear"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: clearText.implicitWidth + 12
            height: 24
            radius: 6
            color: clearArea.containsMouse ? "#141414" : "transparent"
            Text {
                id: clearText
                anchors.centerIn: parent
                text: "Clear all"
                color: clearArea.containsMouse ? "#ffffff" : "#9aa3ad"
                font.pixelSize: 12
            }
            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: tab.clearRequested()
            }
        }
    }

    Flickable {
        id: flick
        visible: tab.groups.length > 0
        anchors.top: head.bottom
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        contentHeight: Math.max(leftColumn.height, rightColumn.height)
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

        // Cards alternate between the two columns, so each column stacks without gaps.
        Column {
            id: leftColumn
            width: (flick.width - 12) / 2
            spacing: 12
            Repeater {
                model: tab.groups.filter((g, i) => i % 2 === 0)
                delegate: GroupCard {}
            }
        }
        Column {
            id: rightColumn
            x: leftColumn.width + 12
            width: leftColumn.width
            spacing: 12
            Repeater {
                model: tab.groups.filter((g, i) => i % 2 === 1)
                delegate: GroupCard {}
            }
        }
    }

    Column {
        objectName: "notifEmpty"
        visible: tab.groups.length === 0
        anchors.centerIn: parent
        spacing: 4
        Text {
            objectName: "notifEmptyTitle"
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No notifications"
            color: "#ffffff"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "New ones will be saved here."
            color: "#9aa3ad"
            font.pixelSize: 13
        }
    }

    component GroupCard: Rectangle {
        id: card
        required property var modelData
        width: parent.width
        height: cardColumn.height + 20
        radius: 16
        color: "#141414"

        Column {
            id: cardColumn
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 2

            Item {
                width: parent.width
                height: 26
                Kirigami.Icon {
                    id: appIcon
                    x: 6
                    y: 2
                    width: 18
                    height: 18
                    source: card.modelData.icon || "preferences-desktop-notification"
                    fallback: "preferences-desktop-notification"
                }
                Text {
                    anchors.left: appIcon.right
                    anchors.leftMargin: 8
                    anchors.right: countText.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: appIcon.verticalCenter
                    text: card.modelData.app
                    color: "#dfe3e8"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    id: countText
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: appIcon.verticalCenter
                    text: card.modelData.rows.length > 1 ? card.modelData.rows.length : ""
                    color: "#9aa3ad"
                    font.pixelSize: 12
                }
            }

            Repeater {
                model: card.modelData.rows
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool isNew: L.isNewItem(modelData, tab.lastSeen)
                    objectName: "notifRow"
                    width: cardColumn.width
                    height: 46
                    radius: 10
                    color: hover.hovered ? "#1f1f21" : "transparent"

                    HoverHandler { id: hover }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: tab.openRequested(row.modelData.id, row.modelData.desktopEntry || "")
                    }

                    Rectangle {
                        objectName: "notifDot"
                        visible: row.isNew
                        x: 8
                        anchors.verticalCenter: titleText.verticalCenter
                        width: 7
                        height: 7
                        radius: 4
                        color: "#ffb340"
                    }
                    Text {
                        id: titleText
                        x: 22
                        y: 7
                        width: timeText.x - x - 10
                        text: row.modelData.title
                        color: row.isNew ? "#ffffff" : "#c5cad0"
                        font.pixelSize: 12
                        font.weight: row.isNew ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }
                    Text {
                        id: timeText
                        objectName: "notifTime"
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.baseline: titleText.baseline
                        text: L.ago(row.modelData.time, tab.now())
                        color: "#6c737c"
                        font.pixelSize: 11
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        x: 22
                        anchors.top: titleText.bottom
                        anchors.topMargin: 3
                        width: removeButton.x - x - 10
                        text: row.modelData.body
                        color: "#9aa3ad"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        id: removeButton
                        objectName: "notifRemove"
                        visible: hover.hovered
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        width: 20
                        height: 20
                        radius: 10
                        color: removeArea.containsMouse ? "#2c2c2e" : "transparent"
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 11
                            height: 11
                            source: "window-close-symbolic"
                            color: removeArea.containsMouse ? "#ffffff" : "#9aa3ad"
                            isMask: true
                        }
                        MouseArea {
                            id: removeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: tab.removeRequested(row.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
