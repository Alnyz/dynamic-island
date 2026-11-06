import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

// Connected Bluetooth devices and their battery, shown from the Bluetooth quick button.
QQC.Popup {
    id: popup

    // [{name, icon, battery (-1 unknown)}] from BluetoothWatcher.
    property var devices: []

    padding: 12
    width: 260
    modal: false
    closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside
    background: Rectangle {
        radius: 14
        color: palette.alternateBase
        border.color: palette.dark
    }

    contentItem: Column {
        spacing: 8
        Text {
            text: "BLUETOOTH DEVICES"
            color: palette.placeholderText
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }
        Text {
            objectName: "btNone"
            visible: popup.devices.length === 0
            text: "No devices connected"
            color: palette.placeholderText
            font.pixelSize: 12
        }
        Repeater {
            model: popup.devices
            delegate: Row {
                required property var modelData
                required property int index
                objectName: "btDevice" + index
                width: popup.availableWidth
                spacing: 10
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    source: modelData.icon || "bluetooth"
                    fallback: "bluetooth"
                    color: palette.windowText
                    isMask: true
                }
                Column {
                    width: parent.width - 28
                    spacing: 4
                    Item {
                        width: parent.width
                        height: nameText.implicitHeight
                        Text {
                            id: nameText
                            width: parent.width - batteryText.implicitWidth - 8
                            text: modelData.name
                            color: palette.windowText
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            id: batteryText
                            objectName: "btBattery" + index
                            anchors.right: parent.right
                            text: modelData.battery >= 0 ? modelData.battery + "%" : "—"
                            color: modelData.battery >= 0 && modelData.battery <= 15 ? "#ff6b6b" : palette.placeholderText
                            font.pixelSize: 12
                            font.features: { "tnum": 1 }
                        }
                    }
                    // How full, when the device says.
                    Rectangle {
                        visible: modelData.battery >= 0
                        width: parent.width
                        height: 3
                        radius: 1.5
                        color: palette.button
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, modelData.battery)) / 100
                            height: parent.height
                            radius: parent.radius
                            color: modelData.battery <= 15 ? "#ff6b6b" : "#30d158"
                        }
                    }
                }
            }
        }
    }
}
