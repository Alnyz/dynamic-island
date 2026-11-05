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

    SignalSpy { id: phaseSpy; signalName: "phaseFinished" }
    SignalSpy { id: doneSpy; signalName: "finished" }

    function finishPhase(timer) {
        t += timer.remainingMs
        timer.tick()
    }

    function test_pomodoro_cycles_with_a_long_break() {
        const timer = make()
        phaseSpy.target = timer
        phaseSpy.clear()
        doneSpy.target = timer
        doneSpy.clear()
        timer.startPomodoro()
        compare(timer.phase, "work")
        compare(timer.round, 1)
        compare(timer.remainingMs, 25 * 60000)
        const seen = []
        for (let i = 0; i < 8; ++i) {
            finishPhase(timer)
            seen.push(timer.phase + timer.round)
        }
        compare(seen, ["break1", "work2", "break2", "work3", "break3", "work4", "longBreak4", "work5"])
        compare(phaseSpy.count, 8)
        compare(phaseSpy.signalArguments[0][0], "work")
        compare(phaseSpy.signalArguments[0][1], "break")
        // A Pomodoro phase change isn't a plain "timer done".
        compare(doneSpy.count, 0)
        compare(timer.running, true)
    }

    function test_break_lengths() {
        const timer = make()
        timer.startPomodoro()
        finishPhase(timer)
        compare(timer.phase, "break")
        compare(timer.remainingMs, 5 * 60000)
        timer.round = 4
        timer.phase = "work"
        finishPhase(timer)
        compare(timer.phase, "longBreak")
        compare(timer.remainingMs, 15 * 60000)
    }

    function test_skip_and_leave_pomodoro() {
        const timer = make()
        phaseSpy.target = timer
        phaseSpy.clear()
        timer.startPomodoro()
        timer.skipPhase()
        compare(timer.phase, "break")
        compare(phaseSpy.count, 1)
        // A plain timer ends Pomodoro mode.
        timer.start(3)
        compare(timer.pomodoro, false)
        compare(timer.phase, "")
        timer.startPomodoro()
        timer.reset()
        compare(timer.pomodoro, false)
        compare(timer.round, 0)
        // Skip does nothing outside Pomodoro.
        timer.skipPhase()
        compare(phaseSpy.count, 1)
    }
}
