import QtQuick
import org.kde.kirigami as Kirigami

// Files dropped on the island; drag one out to drop it into any app.
Item {
    id: tab

    property var files: []
    // The list lives with the island, so changes go out instead of being stored here.
    signal edited(var files)

    function setFiles(list) { edited(list) }
    function nameOf(url) {
        return decodeURIComponent(url.substring(url.lastIndexOf("/") + 1))
    }
    function iconOf(url) {
        const ext = url.substring(url.lastIndexOf(".") + 1).toLowerCase()
        return ext === "pdf" ? "application-pdf" : ["zip", "tar", "gz", "7z", "rar"].includes(ext) ? "application-x-archive"
             : ["mp3", "flac", "ogg", "wav", "m4a"].includes(ext) ? "audio-x-generic" : ["mp4", "mkv", "webm", "mov"].includes(ext) ? "video-x-generic"
             : "text-x-generic"
    }
    function isImage(url) {
        return /\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(url)
    }

    Item {
        id: head
        width: parent.width
        height: 16
        Text {
            text: "SHELF"
            color: "#9aa3ad"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }
        Text {
            objectName: "shelfClear"
            visible: tab.files.length > 0
            anchors.right: parent.right
            text: "Clear"
            color: clearArea.containsMouse ? Qt.lighter(palette.accent, 1.15) : palette.accent
            font.pixelSize: 12
            font.weight: Font.Medium
            MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                onClicked: tab.setFiles([])
            }
        }
    }

    Rectangle {
        id: well
        anchors.top: head.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        radius: 16
        color: drop.containsDrag ? "#0b1a2e" : "#0a0a0a"
        border.color: drop.containsDrag ? palette.accent : "#262626"

        Text {
            objectName: "shelfEmpty"
            visible: tab.files.length === 0
            anchors.centerIn: parent
            text: "Drag files here to keep them for later"
            color: "#9aa3ad"
            font.pixelSize: 13
        }

        Flow {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14
            Repeater {
                model: tab.files
                delegate: Item {
                    id: file
                    required property string modelData
                    required property int index
                    objectName: "shelfFile-" + index
                    width: 84
                    height: 92

                    Item {
                        id: chip
                        width: parent.width
                        height: parent.height
                        Drag.dragType: Drag.Automatic
                        Drag.active: dragArea.drag.active
                        Drag.supportedActions: Qt.CopyAction
                        Drag.mimeData: { "text/uri-list": file.modelData }
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 56
                            height: 56
                            radius: 12
                            color: dragArea.containsMouse ? "#1f1f1f" : "#161616"
                            clip: true
                            Image {
                                visible: tab.isImage(file.modelData)
                                anchors.fill: parent
                                source: visible ? file.modelData : ""
                                sourceSize: Qt.size(112, 112)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Kirigami.Icon {
                                visible: !tab.isImage(file.modelData)
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                source: tab.iconOf(file.modelData)
                            }
                        }
                        Text {
                            y: 62
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: tab.nameOf(file.modelData)
                            color: "#e5e9f0"
                            font.pixelSize: 12
                            elide: Text.ElideMiddle
                        }
                    }
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        drag.target: chip
                        onReleased: { chip.x = 0; chip.y = 0 }
                    }
                    Rectangle {
                        objectName: "shelfRemove-" + file.index
                        visible: dragArea.containsMouse || removeArea.containsMouse
                        x: parent.width / 2 + 18
                        y: -6
                        width: 20
                        height: 20
                        radius: 10
                        color: "#2a2a2a"
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            source: "window-close-symbolic"
                            color: "#ffffff"
                            isMask: true
                        }
                        MouseArea {
                            id: removeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: tab.setFiles(tab.files.filter((f, i) => i !== file.index))
                        }
                    }
                }
            }
        }

        DropArea {
            id: drop
            anchors.fill: parent
            onEntered: drag => drag.accepted = drag.hasUrls
            onDropped: d => tab.setFiles(tab.files.concat(d.urls.map(u => String(u)).filter(u => !tab.files.includes(u))))
        }
    }
}
