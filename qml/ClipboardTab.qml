import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami
import "logic.js" as L

// Copy history from ClipboardHistory (or plain objects in tests). Changes go out as signals.
Item {
    id: tab

    property var items: []
    property string query: ""
    property string kind: "all"
    property string selectedId: ""
    property var now: () => Date.now()
    readonly property bool typing: search.activeFocus

    signal copyRequested(string id)
    signal pinRequested(string id, bool on)
    signal removeRequested(string id)
    signal clearRequested()

    readonly property var rows: L.clipRows(items, query, kind)
    readonly property var visibleItems: rows.filter(r => !r.header)
    readonly property var selected: visibleItems.find(r => r.id === selectedId) || null

    // Keep a selection whenever the list has something in it.
    onVisibleItemsChanged: if (!visibleItems.some(r => r.id === selectedId)) selectedId = visibleItems.length ? (visibleItems.find(r => !r.pinned) || visibleItems[0]).id : ""
    Component.onCompleted: visibleItemsChanged()


    Column {
        id: left
        width: 400
        height: parent.height
        spacing: 10

        Rectangle {
            width: parent.width
            height: 32
            radius: 16
            color: "#141414"
            Kirigami.Icon {
                id: findIcon
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: "edit-find-symbolic"
                color: "#9aa3ad"
                isMask: true
            }
            TextInput {
                id: search
                objectName: "clipSearch"
                anchors.left: findIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: "#ffffff"
                selectionColor: palette.accent
                font.pixelSize: 13
                clip: true
                text: tab.query
                onTextEdited: tab.query = text
                Keys.onEscapePressed: { tab.query = ""; focus = false }
                Text {
                    visible: !search.text
                    text: "Search what you copied"
                    color: "#9aa3ad"
                    font: search.font
                }
            }
        }

        Row {
            spacing: 6
            Repeater {
                model: [["all", "All"], ["text", "Text"], ["link", "Links"], ["image", "Images"]]
                delegate: Pill {
                    required property var modelData
                    objectName: "clipKind-" + modelData[0]
                    height: 26
                    text: modelData[1]
                    selected: tab.kind === modelData[0]
                    onClicked: tab.kind = modelData[0]
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: 2
            model: tab.rows
            boundsBehavior: Flickable.StopAtBounds
            QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: modelData.header ? 26 : 38

                Text {
                    visible: !!row.modelData.header
                    objectName: row.modelData.header ? "clipHeader-" + row.index : ""
                    x: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: row.modelData.header || ""
                    color: "#8a929c"
                    font.pixelSize: 12
                }

                Rectangle {
                    visible: !row.modelData.header
                    objectName: row.modelData.header ? "" : "clipRow-" + row.modelData.id
                    anchors.fill: parent
                    radius: 10
                    readonly property bool isSelected: row.modelData.id === tab.selectedId
                    color: isSelected || rowArea.containsMouse ? "#121212" : "transparent"
                    border.color: isSelected ? "#262626" : "transparent"

                    Row {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 16
                        spacing: 10

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 7
                            color: "#1b1b1b"
                            clip: true
                            Image {
                                visible: row.modelData.kind === "image"
                                anchors.fill: parent
                                source: row.modelData.kind === "image" ? row.modelData.image : ""
                                sourceSize: Qt.size(48, 48)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Kirigami.Icon {
                                visible: row.modelData.kind !== "image"
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                source: row.modelData.kind === "link" ? "link-symbolic" : "insert-text-symbolic"
                                color: "#9aa3ad"
                                isMask: true
                            }
                        }
                        Text {
                            width: parent.width - 34 - (rowEnd.width + 10)
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.kind === "image"
                                ? "Image · " + row.modelData.width + " × " + row.modelData.height
                                : (row.modelData.text || "").replace(/\s+/g, " ")
                            color: "#ffffff"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        Item {
                            id: rowEnd
                            width: Math.max(pinIcon.width, when.implicitWidth)
                            height: 24
                            Kirigami.Icon {
                                id: pinIcon
                                visible: !!row.modelData.pinned
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                source: "pin-symbolic"
                                color: palette.accent
                                isMask: true
                            }
                            Text {
                                id: when
                                visible: !row.modelData.pinned
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.time ? L.ago(row.modelData.time, tab.now()) : ""
                                color: "#8a929c"
                                font.pixelSize: 12
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: tab.selectedId = row.modelData.id
                    }
                }
            }
        }
    }

    Text {
        objectName: "clipEmpty"
        visible: tab.rows.length === 0
        anchors.horizontalCenter: left.horizontalCenter
        y: 130
        text: tab.items.length ? "Nothing matches" : "Nothing copied yet"
        color: "#9aa3ad"
        font.pixelSize: 13
    }

    Column {
        id: right
        x: left.width + 28
        width: parent.width - x
        height: parent.height
        spacing: 10

        Text {
            text: "PREVIEW"
            color: "#9aa3ad"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }

        Rectangle {
            width: parent.width
            height: parent.height - y - actions.height - meta.height - 2 * parent.spacing
            radius: 14
            color: "#0c0c0c"
            border.color: "#1c1c1c"
            clip: true

            Text {
                objectName: "clipPreview"
                visible: tab.selected !== null && tab.selected.kind !== "image"
                anchors.fill: parent
                anchors.margins: 16
                text: tab.selected && tab.selected.kind !== "image" ? tab.selected.text : ""
                color: tab.selected && tab.selected.kind === "link" ? "#7cb8ff" : "#e5e9f0"
                font.pixelSize: 14
                lineHeight: 1.3
                wrapMode: Text.Wrap
                elide: Text.ElideRight
            }
            Image {
                visible: tab.selected !== null && tab.selected.kind === "image"
                anchors.fill: parent
                anchors.margins: 10
                source: tab.selected && tab.selected.kind === "image" ? tab.selected.image : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }

        Text {
            id: meta
            objectName: "clipMeta"
            text: tab.selected ? L.clipMeta(tab.selected, tab.now()) : " "
            color: "#9aa3ad"
            font.pixelSize: 12
        }

        Item {
            id: actions
            width: parent.width
            height: 32
            Row {
                spacing: 8
                Pill {
                    objectName: "clipCopy"
                    height: 32
                    primary: true
                    enabled: tab.selected !== null
                    opacity: enabled ? 1 : 0.4
                    iconName: "edit-copy-symbolic"
                    text: "Copy"
                    onClicked: {
                        tab.copyRequested(tab.selectedId)
                        toast.opacity = 1
                        toastTimer.restart()
                    }
                }
                Pill {
                    objectName: "clipPin"
                    height: 32
                    enabled: tab.selected !== null
                    opacity: enabled ? 1 : 0.4
                    iconName: "pin-symbolic"
                    text: tab.selected && tab.selected.pinned ? "Unpin" : "Pin"
                    onClicked: tab.pinRequested(tab.selectedId, !tab.selected.pinned)
                }
                Pill {
                    objectName: "clipDelete"
                    height: 32
                    enabled: tab.selected !== null
                    opacity: enabled ? 1 : 0.4
                    iconName: "edit-delete-symbolic"
                    text: "Delete"
                    onClicked: tab.removeRequested(tab.selectedId)
                }
            }
            Pill {
                objectName: "clipClear"
                anchors.right: parent.right
                height: 32
                text: "Clear history"
                toolTip: "Pinned items stay"
                onClicked: tab.clearRequested()
            }
        }
    }

    Rectangle {
        id: toast
        objectName: "clipToast"
        visible: opacity > 0
        opacity: 0
        anchors.horizontalCenter: right.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44
        width: toastText.implicitWidth + 24
        height: 26
        radius: 13
        color: "#ffffff"
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Text {
            id: toastText
            anchors.centerIn: parent
            text: "Copied"
            color: "#000000"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        Timer {
            id: toastTimer
            interval: 1200
            onTriggered: toast.opacity = 0
        }
    }
}
