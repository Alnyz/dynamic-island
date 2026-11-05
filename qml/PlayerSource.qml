import QtQuick
import "logic.js" as L

QtObject {
    id: source

    property var players: []
    property var now: () => Date.now()
    property real pauseTimeoutMs: L.PAUSE_TIMEOUT_MS
    // A player picked in the Music tab wins over the automatic choice until it goes away or
    // another player starts playing.
    property var pinned: null
    readonly property var player: pinned !== null && players.indexOf(pinned) >= 0 ? pinned : chosen
    // Each real player once, for picking.
    readonly property var choices: L.distinctPlayers(players)
    function pin(p) { pinned = p }
    // The chosen player's cover, kept through the gaps browsers leave (see L.heldArt).
    readonly property string artUrl: held.url

    property var held: ({ key: "", url: "" })
    function artKey(p) { return (p.desktopEntry || "") + "\n" + (p.artist || "") + "\n" + (p.track || "") }
    function updateArt() {
        const p = player
        held = p ? L.heldArt(held, { key: artKey(p), url: p.artUrl || "" })
                 : { key: "", url: "" }
        // Brave and other browsers often never send the cover of a skipped-to song; look it up instead.
        lookupTimer.stop()
        if (!coverLookup || !p || held.url || !p.track || !p.artist)
            return
        if (lookups.has(held.key)) {
            if (lookups.get(held.key))
                held = { key: held.key, url: lookups.get(held.key) }
            return
        }
        lookupTimer.restart()
    }

    // Look up covers the player never sends, on iTunes by artist and title.
    property bool coverLookup: false
    // Gives the player a moment to send its own cover first.
    property int lookupDelayMs: 1000
    // Song key -> cover URL, or "" when the search found nothing; not searched again this session.
    property var lookups: new Map()
    property var fetch: function(url, done) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (xhr.status !== 200) {
                done("HTTP " + xhr.status, null)
                return
            }
            try {
                done(null, JSON.parse(xhr.responseText))
            } catch (e) {
                done(String(e), null)
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }
    onCoverLookupChanged: updateArt()

    property Timer lookupTimer: Timer {
        interval: source.lookupDelayMs
        onTriggered: {
            const p = source.player
            if (!p || source.held.url)
                return
            const key = source.held.key
            const artist = p.artist, track = p.track
            source.fetch(L.coverSearchUrl(artist, track), function(err, data) {
                // A failed request is tried again on the next song change, not remembered as "no cover".
                if (err || !data)
                    return
                const url = L.pickCover(data.results, artist, track)
                source.lookups.set(key, url)
                if (url && source.held.key === key && !source.held.url)
                    source.held = { key: key, url: url }
            })
        }
    }
    onChosenChanged: Qt.callLater(updateArt)
    onPinnedChanged: Qt.callLater(updateArt)
    // The track and its cover arrive as separate change signals; read them once both have landed.
    property Connections artWatcher: Connections {
        target: source.player
        ignoreUnknownSignals: true
        function onArtUrlChanged() { Qt.callLater(source.updateArt) }
        function onTrackChanged() { Qt.callLater(source.updateArt) }
        function onArtistChanged() { Qt.callLater(source.updateArt) }
    }

    property var chosen: null
    // Per player: last seen status and when it started playing / paused.
    property var history: new Map()

    function reevaluate() {
        const t = now()
        const next = new Map()
        const entries = players.map(p => {
            let h = history.get(p)
            if (h && h.status !== p.playbackStatus && p.playbackStatus === L.Status.Playing && pinned !== null
                    && p !== pinned && (p.objectName || "") !== (pinned.objectName || ""))
                pinned = null
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
        if (pinned !== null && players.indexOf(pinned) < 0)
            pinned = null

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
