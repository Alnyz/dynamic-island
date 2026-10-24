import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami
import Island
import "logic.js" as L

Row {
    id: quick

    spacing: 6
    // objectName suffixes ("volume", "wifi", ...) of buttons to leave out.
    property var hidden: []

    Rectangle {
        visible: SystemStatus.battery >= 0 && !quick.hidden.includes("battery")
        anchors.verticalCenter: parent.verticalCenter
        width: battRow.implicitWidth + 24
        height: 30
        radius: 15
        color: "#141414"

        Row {
            id: battRow
            anchors.centerIn: parent
            spacing: 6
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                readonly property int level: Math.round(SystemStatus.battery / 20) * 20
                source: "battery-" + String(level).padStart(3, "0") + (SystemStatus.charging ? "-charging" : "")
                color: "#ffffff"
                isMask: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemStatus.battery + "%"
                color: "#ffffff"
                font.pixelSize: 12
            }
        }
    }

    QuickButton {
        objectName: "qb-volume"
        label: SystemStatus.muted ? "Unmute" : "Mute (scroll to change volume, " + SystemStatus.volume + "%)"
        iconName: SystemStatus.muted ? "audio-volume-muted" : "audio-volume-high"
        onClicked: SystemStatus.toggleMute()
        property int wheelAccum: 0
        onScrolled: delta => {
            const r = L.wheelSteps(wheelAccum, delta)
            wheelAccum = r.accum
            if (r.steps !== 0)
                SystemStatus.changeVolume(r.steps * 5)
        }
    }
    QuickButton {
        objectName: "qb-wifi"
        label: "Wi-Fi"
        on: SystemStatus.wifi
        iconName: SystemStatus.wifi ? "network-wireless" : "network-wireless-disconnected"
        onClicked: SystemStatus.setWifi(!SystemStatus.wifi)
    }
    QuickButton {
        objectName: "qb-bluetooth"
        label: "Bluetooth"
        on: SystemStatus.bluetooth
        iconName: "network-bluetooth-activated"
        onClicked: SystemStatus.setBluetooth(!SystemStatus.bluetooth)
    }
    QuickButton {
        objectName: "qb-dnd"
        label: "Do not disturb"
        on: SystemStatus.dnd
        iconName: "notifications-disabled"
        onClicked: SystemStatus.setDnd(!SystemStatus.dnd)
    }
    QuickButton {
        objectName: "qb-awake"
        label: "Keep screen awake"
        on: SystemStatus.keepAwake
        iconName: "system-suspend-inhibited"
        onClicked: SystemStatus.setKeepAwake(!SystemStatus.keepAwake)
    }
    QuickButton {
        objectName: "qb-screenshot"
        label: "Screenshot"
        iconName: "camera-photo-symbolic"
        onClicked: SystemStatus.screenshot()
    }
    QuickButton {
        objectName: "qb-lock"
        label: "Lock screen"
        iconName: "system-lock-screen-symbolic"
        onClicked: SystemStatus.lock()
    }

    component QuickButton: Rectangle {
        id: button
        property string iconName
        property string label
        property bool on: false
        signal clicked()
        signal scrolled(int delta)

        visible: !quick.hidden.includes(objectName.slice(3))
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: 15
        color: on ? palette.accent : "#141414"

        Kirigami.Icon {
            anchors.centerIn: parent
            width: 15
            height: 15
            source: button.iconName
            color: "#ffffff"
            isMask: true
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.clicked()
            onWheel: wheel => button.scrolled(wheel.angleDelta.y)
        }
        QQC.ToolTip.visible: area.containsMouse
        QQC.ToolTip.text: button.label
        QQC.ToolTip.delay: 500
    }
}
