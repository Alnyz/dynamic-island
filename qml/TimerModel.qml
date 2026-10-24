import QtQuick

QtObject {
    id: timer

    property var now: () => Date.now()
    readonly property real remainingMs: remaining
    readonly property bool running: endMs > 0
    readonly property bool paused: pausedRemainingMs > 0
    signal finished()

    // Remaining time comes from an end timestamp, so sleep or a closed panel can't skew it.
    property real endMs: 0
    property real pausedRemainingMs: 0
    property real remaining: 0
    // The full length including added minutes, for progress bars.
    property real durationMs: 0

    function start(minutes) {
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
            finished()
        }
    }

    property Timer ticker: Timer {
        interval: 1000
        repeat: true
        running: timer.running
        onTriggered: timer.tick()
    }
}
