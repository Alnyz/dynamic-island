import QtQuick
import QtTest
import "../qml"

Item {
    id: stage
    width: 400
    height: 300

    Component {
        id: comp
        BluetoothDevices { x: 20; y: 20 }
    }

    TestCase {
        name: "BluetoothDevices"
        when: windowShown

        function test_lists_devices_and_battery() {
            const p = createTemporaryObject(comp, stage, { devices: [
                { name: "Noise Earbuds", icon: "audio-headset", battery: 80 },
                { name: "Toad One", icon: "input-mouse", battery: 9 },
                { name: "JBL Go 3", icon: "audio-card", battery: -1 }
            ] })
            p.open()
            tryCompare(p, "opened", true)
            compare(findChild(p.contentItem, "btBattery0").text, "80%")
            compare(findChild(p.contentItem, "btBattery1").text, "9%")
            compare(findChild(p.contentItem, "btBattery1").color, Qt.color("#ff6b6b"))
            compare(findChild(p.contentItem, "btBattery2").text, "—")
            compare(findChild(p.contentItem, "btNone").visible, false)
        }

        function test_nothing_connected() {
            const p = createTemporaryObject(comp, stage, { devices: [] })
            p.open()
            tryCompare(p, "opened", true)
            verify(findChild(p.contentItem, "btNone").visible)
        }

        function test_closes_on_click_outside() {
            const p = createTemporaryObject(comp, stage, { devices: [] })
            p.open()
            tryCompare(p, "opened", true)
            mouseClick(stage, 390, 290)
            tryCompare(p, "visible", false)
        }
    }
}
