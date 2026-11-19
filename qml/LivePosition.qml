import QtQuick
import "logic.js" as L

// The player's position in microseconds, counted forward while it plays. Some players (Spotifry)
// never announce their position as it moves, as MPRIS allows, so the copy Plasma holds is only
// right when Plasma first sees the player and after a jump (a seek or a new song). Asking Plasma
// to read it again does nothing either. So the clock reads that copy only then, counts on its own
// in between, and is made once and shared: a clock made later would start from a stale copy.
QtObject {
    id: clock

    property var player: null
    // Nothing ticks while the bar isn't on screen; the count still runs.
    property bool active: true
    readonly property bool playing: player !== null && player.playbackStatus === L.Status.Playing
    readonly property real length: player ? player.length || 0 : 0
    readonly property real value: {
        tick
        if (!player)
            return 0
        const ahead = counting ? (Date.now() - at) * 1000 : 0
        return length > 0 ? Math.min(base + ahead, length) : base + ahead
    }

    property real base: 0
    property real at: Date.now()
    property int tick: 0
    // Whether the count is running; follows playing, but changed only after the time so far is kept.
    property bool counting: false

    // Takes the player's own position: when the clock gets a player, and after a jump.
    function sync() {
        base = player ? player.position || 0 : 0
        at = Date.now()
        counting = playing
        tick++
    }
    // Pausing or playing keeps the counted time instead of rereading the stale copy.
    function hold() {
        // Worked out now: value itself only moves on each tick.
        const now = base + (counting ? (Date.now() - at) * 1000 : 0)
        base = length > 0 ? Math.min(now, length) : now
        at = Date.now()
        counting = playing
        tick++
    }
    // Deferred: syncing while the binding above is still being worked out makes a binding loop.
    onPlayerChanged: Qt.callLater(sync)
    onPlayingChanged: hold()

    property Connections follow: Connections {
        target: clock.player
        ignoreUnknownSignals: true
        function onPositionChanged() { Qt.callLater(clock.sync) }
        function onTrackChanged() { Qt.callLater(clock.sync) }
    }
    property Timer ticker: Timer {
        interval: 200
        repeat: true
        running: clock.playing && clock.active
        onTriggered: clock.tick++
    }
}
