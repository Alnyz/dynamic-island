import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15
import QtQuick.Controls 2.15 as QQC

// The packages waiting for an update (UpdatesWatcher), and a button that upgrades them in a terminal.
Item {
    id: tab

    // [{name, from, to}]
    property var packages: []
    signal upgradeRequested()

    Item {
        id: head
        width: parent.width
        height: 34
        Text {
            objectName: "updatesTitle"
            anchors.verticalCenter: parent.verticalCenter
            text: tab.packages.length === 0 ? "Everything is up to date"
                : tab.packages.length === 1 ? "1 update waiting" : tab.packages.length + " updates waiting"
            color: ipal.windowText
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        Pill {
            objectName: "updatesUpgrade"
            visible: tab.packages.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            primary: true
            iconName: "system-software-update"
            text: "Update now"
            toolTip: "Opens a terminal to run the upgrade"
            onClicked: tab.upgradeRequested()
        }
    }

    ListView {
        objectName: "updatesList"
        anchors.top: head.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        spacing: 2
        model: tab.packages
        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }
        delegate: Rectangle {
            required property var modelData
            required property int index
            objectName: "updateRow" + index
            width: ListView.view.width - 10
            height: 28
            radius: 8
            color: index % 2 ? "transparent" : ipal.base
            Text {
                x: 10
                width: parent.width * 0.45
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                color: ipal.windowText
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.5
                horizontalAlignment: Text.AlignRight
                text: modelData.from + "  →  " + modelData.to
                color: ipal.placeholderText
                font.pixelSize: 12
                elide: Text.ElideLeft
            }
        }
    }
}
