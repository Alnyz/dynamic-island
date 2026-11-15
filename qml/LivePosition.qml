import QtQuick
import "logic.js" as L

// The player's position in microseconds, counted forward while it plays. Some players (Spotifry)
// never announce their position as it moves, so the value Plasma holds only changes on a seek
// or a new song; this carries it on between those and takes the real one whenever it changes.
QtObject {
    id: clock

    property var player: null
    // Nothing ticks while the bar isn't on screen.
    property bool active: true
    readonly property bool playing: player !== null && player.playbackStatus === L.Status.Playing
    readonly property real length: player ? player.length || 0 : 0
    readonly property real value: {
        tick
        if (!player)
            return 0
        const ahead = playing ? (Date.now() - at) * 1000 : 0
        return length > 0 ? Math.min(base + ahead, length) : base + ahead
    }

    property real base: 0
    property real at: Date.now()
    property int tick: 0

    function sync() {
        base = player ? player.position || 0 : 0
        at = Date.now()
        tick++
    }
    // Deferred: syncing while the binding above is still being worked out makes a binding loop.
    onPlayerChanged: Qt.callLater(sync)
    onPlayingChanged: Qt.callLater(sync)
    onActiveChanged: if (active) Qt.callLater(sync)

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
