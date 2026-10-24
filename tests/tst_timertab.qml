import QtQuick
import QtTest
import "../qml"

Item {
    id: stage
    width: 860
    height: 360

    property real t: 0

    Component {
        id: comp
        Item {
            width: 860
            height: 360
            property alias tab: tab
            property alias model: model
            TimerModel { id: model; now: () => stage.t }
            TimerTab { id: tab; anchors.fill: parent; timer: model }
        }
    }

    TestCase {
        name: "TimerTab"
        when: windowShown

        function make() {
            stage.t = 0
            return createTemporaryObject(comp, stage)
        }

        function test_preset_sets_without_starting() {
            const h = make()
            mouseClick(findChild(h.tab, "preset-10"))
            compare(h.tab.setMinutes, 10)
            compare(h.model.running, false)
        }

        function test_scroll_on_tape_changes_minutes() {
            const h = make()
            const tape = findChild(h.tab, "tape")
            const before = h.tab.setMinutes
            mouseWheel(tape, tape.width / 2, 20, 0, 120)
            compare(h.tab.setMinutes, before + 1)
            mouseWheel(tape, tape.width / 2, 20, 0, -240)
            compare(h.tab.setMinutes, before - 1)
        }

        function test_drag_tape_changes_minutes() {
            const h = make()
            const tape = findChild(h.tab, "tape")
            const before = h.tab.setMinutes
            mouseDrag(tape, tape.width / 2, 20, -128, 0)
            compare(h.tab.setMinutes, before + 2)
        }

        function test_minutes_stay_in_range() {
            const h = make()
            h.tab.setMinutes = 1
            const tape = findChild(h.tab, "tape")
            mouseWheel(tape, tape.width / 2, 20, 0, -120)
            compare(h.tab.setMinutes, 1)
        }

        function test_start_and_controls() {
            const h = make()
            mouseClick(findChild(h.tab, "preset-5"))
            mouseClick(findChild(h.tab, "timerStart"))
            compare(h.model.running, true)
            compare(h.model.remainingMs, 300000)
            // The running controls replace the presets on the next layout pass.
            waitForItemPolished(findChild(h.tab, "timerAdd1").parent)
            mouseClick(findChild(h.tab, "timerAdd1"))
            compare(h.model.remainingMs, 360000)
            mouseClick(findChild(h.tab, "timerToggle"))
            compare(h.model.paused, true)
            mouseClick(findChild(h.tab, "timerReset"))
            compare(h.model.running || h.model.paused, false)
        }
    }
}
