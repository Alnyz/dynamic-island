import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15
import Qt.labs.settings 1.1
import Qt.labs.platform 1.1 as Platform
import org.kde.kirigami 2.19 as Kirigami
import "logic.js" as L

// The user's own sites and folders, one click each. They are added in Settings.
Item {
    id: tab

    property var links: []
    readonly property string home: decodeURIComponent(Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString().substring(7))
    signal openRequested(string url)
    signal settingsRequested()

    Item {
        id: head
        width: parent.width
        height: 16
        Text {
            text: "QUICK LINKS"
            color: ipal.placeholderText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }
        Text {
            objectName: "linksEdit"
            visible: tab.links.length > 0
            anchors.right: parent.right
            text: "Edit"
            color: editArea.containsMouse ? Qt.lighter(ipal.accent, 1.15) : ipal.accent
            font.pixelSize: 12
            font.weight: Font.Medium
            MouseArea {
                id: editArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                onClicked: tab.settingsRequested()
            }
        }
    }

    Column {
        objectName: "linksEmpty"
        visible: tab.links.length === 0
        anchors.centerIn: parent
        anchors.verticalCenterOffset: head.height / 2
        spacing: 14
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Sites and folders you open every day, one click away"
            color: ipal.placeholderText
            font.pixelSize: 13
        }
        Pill {
            anchors.horizontalCenter: parent.horizontalCenter
            primary: true
            text: "Add links in Settings"
            onClicked: tab.settingsRequested()
        }
    }

    Flow {
        anchors.top: head.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 12

        Repeater {
            model: tab.links
            delegate: Rectangle {
                id: tile
                required property var modelData
                required property int index
                readonly property bool folder: modelData.url.startsWith("file://")
                objectName: "link-" + index
                width: (parent.width - 3 * 12) / 4
                height: 64
                radius: 16
                color: tileArea.containsMouse ? ipal.alternateBase : ipal.base
                border.color: tileArea.containsMouse ? ipal.dark : ipal.button

                Rectangle {
                    id: badge
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 38
                    radius: 11
                    color: Qt.rgba(ipal.accent.r, ipal.accent.g, ipal.accent.b, 0.16)
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: tile.folder ? "folder-symbolic" : "globe-symbolic"
                        color: ipal.accent
                        isMask: true
                    }
                }
                Column {
                    anchors.left: badge.right
                    anchors.leftMargin: 11
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        width: parent.width
                        text: tile.modelData.name || L.linkName(tile.modelData.url)
                        color: ipal.windowText
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: tile.folder ? decodeURIComponent(tile.modelData.url.substring(7)).replace(tab.home, "~") : L.linkName(tile.modelData.url)
                        color: ipal.placeholderText
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }
                }
                MouseArea {
                    id: tileArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.openRequested(tile.modelData.url)
                }
            }
        }
    }
}
