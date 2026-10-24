import QtQuick
import QtTest
import "../qml"

TestCase {
    id: tc
    name: "Timer"

    property real t: 0

    Component {
        id: timerComp
        TimerModel { now: () => tc.t }
    }

    function make() { return createTemporaryObject(timerComp, tc) }

    function init() { t = 0 }

    function test_start_counts_down() {
        const timer = make()
        timer.start(5)
        t = 60000
        timer.tick()
        compare(timer.remainingMs, 240000)
        compare(timer.running, true)
    }

    function test_timer_uses_end_time() {
        const timer = make()
        timer.start(1)
        t = 59000
        timer.tick()
        compare(timer.remainingMs, 1000)
    }

    function test_pause_resume() {
        const timer = make()
        timer.start(1)
        t = 10000
        timer.pause()
        compare(timer.paused, true)
        t = 40000
        timer.resume()
        t = 50000
        timer.tick()
        compare(timer.remainingMs, 40000)
    }

    function test_finished_once() {
        const timer = make()
        const spy = createTemporaryObject(spyComp, tc, { target: timer })
        timer.start(1)
        t = 60000
        timer.tick()
        timer.tick()
        compare(spy.count, 1)
        compare(timer.running, false)
    }

    function test_reset() {
        const timer = make()
        timer.start(5)
        timer.reset()
        compare(timer.running, false)
        compare(timer.remainingMs, 0)
    }

    function test_add_minutes() {
        const timer = make()
        timer.start(5)
        timer.addMinutes(1)
        compare(timer.remainingMs, 360000)
        compare(timer.durationMs, 360000)
        timer.pause()
        timer.addMinutes(5)
        compare(timer.pausedRemainingMs, 660000)
        timer.reset()
        timer.addMinutes(1)
        compare(timer.running, false)
    }

    function test_duration_for_progress() {
        const timer = make()
        timer.start(10)
        compare(timer.durationMs, 600000)
        timer.reset()
        compare(timer.durationMs, 0)
    }

    Component {
        id: spyComp
        SignalSpy { signalName: "finished" }
    }
}
