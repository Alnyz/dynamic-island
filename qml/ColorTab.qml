import QtQuick
import org.kde.kirigami as Kirigami
import "logic.js" as L

// Pick a colour anywhere on screen; its codes copy with a click.
Item {
    id: tab

    // Newest first.
    property var colors: []
    property string selected: ""
    readonly property string current: colors.includes(selected) ? selected : colors.length ? colors[0] : ""
    readonly property var formats: current ? L.colorFormats(current) : null
    property string copiedKey: ""

    signal pickRequested()
    signal copyRequested(string text)

    function copy(key, text) {
        copyRequested(text)
        copiedKey = key
        copiedTimer.restart()
    }
    Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: tab.copiedKey = ""
    }

    Column {
        id: left
        width: 200
        spacing: 14

        Rectangle {
            objectName: "colorSwatch"
            width: 200
            height: 200
            radius: 22
            color: tab.current || palette.base
            border.color: tab.current ? Qt.rgba(palette.windowText.r, palette.windowText.g, palette.windowText.b, 0.12) : palette.button
            Text {
                visible: !tab.current
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "Pick any colour on your screen"
                color: palette.placeholderText
                font.pixelSize: 13
            }
        }
        Pill {
            objectName: "pickColor"
            width: 200
            primary: true
            iconName: "color-picker-symbolic"
            text: "Pick a colour"
            onClicked: tab.pickRequested()
        }
    }

    Column {
        anchors.left: left.right
        anchors.leftMargin: 30
        anchors.right: parent.right
        spacing: 10

        Repeater {
            model: [
                { key: "hex", label: "HEX" },
                { key: "rgb", label: "RGB" },
                { key: "hsl", label: "HSL" }
            ]
            delegate: Rectangle {
                required property var modelData
                readonly property string value: tab.formats ? tab.formats[modelData.key] : "-"
                objectName: "format-" + modelData.key
                width: parent.width
                height: 50
                radius: 14
                color: rowArea.containsMouse && tab.formats ? palette.alternateBase : palette.base
                border.color: palette.button
                Text {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: palette.placeholderText
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                }
                Text {
                    x: 70
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.value
                    color: tab.formats ? palette.windowText : palette.mid
                    font.pixelSize: 14
                    font.features: { "tnum": 1 }
                }
                Row {
                    visible: tab.formats !== null
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        visible: tab.copiedKey === modelData.key
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Copied"
                        color: palette.accent
                        font.pixelSize: 12
                    }
                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15
                        height: 15
                        source: tab.copiedKey === modelData.key ? "checkmark-symbolic" : "edit-copy-symbolic"
                        color: tab.copiedKey === modelData.key ? palette.accent : palette.placeholderText
                        isMask: true
                    }
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    enabled: tab.formats !== null
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.copy(modelData.key, parent.value)
                }
            }
        }

        Item { width: 1; height: 8 }

        Text {
            visible: tab.colors.length > 0
            text: "RECENT"
            color: palette.placeholderText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }
        Flow {
            width: parent.width
            spacing: 10
            Repeater {
                model: tab.colors
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    objectName: "recent-" + index
                    width: 32
                    height: 32
                    radius: 16
                    color: modelData
                    border.width: modelData === tab.current ? 2 : 1
                    border.color: modelData === tab.current ? palette.windowText : Qt.rgba(palette.windowText.r, palette.windowText.g, palette.windowText.b, 0.14)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tab.selected = parent.modelData
                            tab.copy("hex", L.colorFormats(parent.modelData).hex)
                        }
                    }
                }
            }
        }
    }
}
