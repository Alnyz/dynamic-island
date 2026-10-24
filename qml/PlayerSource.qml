import QtQuick
import "logic.js" as L

QtObject {
    id: source

    property var players: []
    property var now: () => Date.now()
    property real pauseTimeoutMs: L.PAUSE_TIMEOUT_MS
    readonly property var player: chosen

    property var chosen: null
    // Per player: last seen status and when it started playing / paused.
    property var history: new Map()

    function reevaluate() {
        const t = now()
        const next = new Map()
        const entries = players.map(p => {
            let h = history.get(p)
            if (!h || h.status !== p.playbackStatus) {
                h = {
                    status: p.playbackStatus,
                    playingSinceMs: p.playbackStatus === L.Status.Playing ? t : (h ? h.playingSinceMs : 0),
                    // A player first seen already paused (e.g. a stale browser entry) gets no 5-minute window.
                    pausedSinceMs: p.playbackStatus === L.Status.Paused ? (h ? t : -Infinity) : (h ? h.pausedSinceMs : 0)
                }
            }
            next.set(p, h)
            return { status: p.playbackStatus, title: p.track, playingSinceMs: h.playingSinceMs, pausedSinceMs: h.pausedSinceMs }
        })
        history = next

        const index = L.pickPlayer(entries, t, pauseTimeoutMs)
        chosen = index >= 0 ? players[index] : null

        // Wake up when the oldest still-shown pause runs out, so the island goes idle without polling.
        let wait = Infinity
        for (const e of entries) {
            if (e.status === L.Status.Paused && e.title && t - e.pausedSinceMs < pauseTimeoutMs)
                wait = Math.min(wait, e.pausedSinceMs + pauseTimeoutMs - t)
        }
        pauseTimer.stop()
        if (wait !== Infinity) {
            pauseTimer.interval = wait
            pauseTimer.start()
        }
    }

    onPlayersChanged: reevaluate()
    onPauseTimeoutMsChanged: reevaluate()

    property Timer pauseTimer: Timer {
        onTriggered: source.reevaluate()
    }

    property Instantiator watchers: Instantiator {
        model: source.players
        delegate: Connections {
            required property var modelData
            target: modelData
            ignoreUnknownSignals: true
            function onPlaybackStatusChanged() { source.reevaluate() }
            function onTrackChanged() { source.reevaluate() }
        }
    }
}
