import QtQuick
import "logic.js" as L

// Lyrics for the current song from LRCLIB (lrclib.net), only while something shows them.
// Sends the artist, title, album and length; nothing else.
QtObject {
    id: lyrics

    property bool enabled: false
    // Set by the lyrics view while it's on screen; no request is made otherwise.
    property bool wanted: false
    property string artist: ""
    property string title: ""
    property string album: ""
    property real lengthUs: 0
    // Waits this long after a song change, so skipping through songs sends nothing.
    property int delayMs: 700

    // "off", "idle", "loading", "synced", "plain", "instrumental" or "none".
    property string state: "off"
    // [{ ms, text }] for synced lyrics.
    property var lines: []
    property string plain: ""

    property var fetch: function(url, done) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (xhr.status === 404) {
                done(null, null)
                return
            }
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

    // Song key -> { state, lines, plain }; remembered for this session.
    property var cache: new Map()
    readonly property string key: artist + "\n" + title + "\n" + Math.round(lengthUs / 1e6)

    // Content first, then state, so whatever reacts to the state sees the matching lines.
    function show(r) {
        lines = r.lines || []
        plain = r.plain || ""
        state = r.state
    }
    function fromRecord(r) {
        if (!r)
            return { state: "none" }
        if (r.instrumental)
            return { state: "instrumental" }
        const parsed = L.parseLrc(r.syncedLyrics)
        if (parsed.length)
            return { state: "synced", lines: parsed }
        if (r.plainLyrics)
            return { state: "plain", plain: r.plainLyrics }
        return { state: "none" }
    }

    function refresh() {
        timer.stop()
        if (!enabled) {
            show({ state: "off" })
            return
        }
        if (!title || !artist) {
            show({ state: "none" })
            return
        }
        if (cache.has(key)) {
            show(cache.get(key))
            return
        }
        show({ state: wanted ? "loading" : "idle" })
        if (wanted)
            timer.restart()
    }

    function load() {
        const k = key
        const a = artist, t = title, al = album, len = lengthUs
        const finish = r => {
            cache.set(k, r)
            if (k === lyrics.key)
                show(r)
        }
        fetch(L.lyricsGetUrl(a, t, al, len), function(err, record) {
            if (k !== lyrics.key)
                return
            if (!err && record) {
                finish(fromRecord(record))
                return
            }
            fetch(L.lyricsSearchUrl(a, t), function(err2, list) {
                if (k !== lyrics.key)
                    return
                // A network failure isn't remembered, so it's tried again next time.
                if (err2) {
                    show({ state: "none" })
                    return
                }
                finish(fromRecord(L.pickLyrics(Array.isArray(list) ? list : [], a, t, len)))
            })
        })
    }

    onKeyChanged: refresh()
    onEnabledChanged: refresh()
    onWantedChanged: refresh()

    property Timer timer: Timer {
        interval: lyrics.delayMs
        onTriggered: lyrics.load()
    }
}
