import QtQuick

QtObject {
    id: timer

    property var now: () => Date.now()
    readonly property real remainingMs: remaining
    readonly property bool running: endMs > 0
    readonly property bool paused: pausedRemainingMs > 0
    signal finished()

    // Pomodoro: focus and break phases follow each other on their own; every longEvery-th
    // break is a long one. phaseFinished replaces finished while it runs.
    property bool pomodoro: false
    property string phase: ""
    property int round: 0
    property int workMinutes: 25
    property int breakMinutes: 5
    property int longBreakMinutes: 15
    property int longEvery: 4
    signal phaseFinished(string ended, string next)

    // Remaining time comes from an end timestamp, so sleep or a closed panel can't skew it.
    property real endMs: 0
    property real pausedRemainingMs: 0
    property real remaining: 0
    // The full length including added minutes, for progress bars.
    property real durationMs: 0

    // A plain timer; leaves Pomodoro mode.
    function start(minutes) {
        pomodoro = false
        phase = ""
        round = 0
        begin(minutes)
    }

    function startPomodoro() {
        pomodoro = true
        round = 1
        phase = "work"
        begin(workMinutes)
    }

    // Ends the current phase now and moves to the next one.
    function skipPhase() {
        if (!pomodoro)
            return
        const ended = phase
        advance()
        phaseFinished(ended, phase)
    }

    function advance() {
        if (phase === "work") {
            phase = round % longEvery === 0 ? "longBreak" : "break"
            begin(phase === "longBreak" ? longBreakMinutes : breakMinutes)
        } else {
            round++
            phase = "work"
            begin(workMinutes)
        }
    }

    function begin(minutes) {
        pausedRemainingMs = 0
        endMs = now() + minutes * 60000
        durationMs = minutes * 60000
        tick()
    }

    function pause() {
        if (!running)
            return
        tick()
        pausedRemainingMs = remaining
        endMs = 0
    }

    function resume() {
        if (!paused)
            return
        endMs = now() + pausedRemainingMs
        pausedRemainingMs = 0
        tick()
    }

    function addMinutes(minutes) {
        if (running)
            endMs += minutes * 60000
        else if (paused)
            pausedRemainingMs += minutes * 60000
        else
            return
        durationMs += minutes * 60000
        tick()
    }

    function reset() {
        pomodoro = false
        phase = ""
        round = 0
        durationMs = 0
        endMs = 0
        pausedRemainingMs = 0
        remaining = 0
    }

    function tick() {
        if (!running)
            return
        remaining = Math.max(0, endMs - now())
        if (remaining === 0) {
            endMs = 0
            if (pomodoro) {
                const ended = phase
                advance()
                phaseFinished(ended, phase)
            } else {
                finished()
            }
        }
    }

    property Timer ticker: Timer {
        interval: 1000
        repeat: true
        running: timer.running
        onTriggered: timer.tick()
    }
}
