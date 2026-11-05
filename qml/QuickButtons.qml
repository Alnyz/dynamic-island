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
    // Connected Bluetooth devices: the emptiest battery shows as a badge on the Bluetooth button.
    property var devices: []
    readonly property var btSummary: L.bluetoothSummary(devices)

    Rectangle {
        visible: SystemStatus.battery >= 0 && !quick.hidden.includes("battery")
        anchors.verticalCenter: parent.verticalCenter
        width: battRow.implicitWidth + 24
        height: 30
        radius: 15
        color: palette.base

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
                color: palette.windowText
                isMask: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemStatus.battery + "%"
                color: palette.windowText
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
        label: quick.btSummary.label
        badge: quick.btSummary.badge
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
        property string badge: ""
        signal clicked()
        signal scrolled(int delta)

        visible: !quick.hidden.includes(objectName.slice(3))
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: 15
        color: on ? palette.accent : palette.base

        Kirigami.Icon {
            anchors.centerIn: parent
            width: 15
            height: 15
            source: button.iconName
            color: parent.on ? "#ffffff" : palette.windowText
            isMask: true
        }
        Rectangle {
            visible: button.badge !== ""
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -4
            anchors.bottomMargin: -3
            width: Math.max(16, badgeText.implicitWidth + 6)
            height: 13
            radius: 6.5
            color: Number(button.badge) <= 15 ? "#ff6b6b" : palette.button
            border.color: palette.window
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: button.badge
                color: Number(button.badge) <= 15 ? "#ffffff" : palette.windowText
                font.pixelSize: 8
                font.weight: Font.Bold
            }
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
