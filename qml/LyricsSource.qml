import QtQuick
import "logic.js" as L

// Lyrics for the current song, only while something shows them. Word-timed ones from
// BetterLyrics, lrc.red and QQ Music (through BetterLyrics) are asked together; LRCLIB, timed by
// line, only when none of them has the song. Sends the artist, title, album and length; nothing else.
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
    // [{ ms, text, words? }] for synced lyrics; words: [{ ms, end, text }] when timed by word.
    property var lines: []
    property string plain: ""

    // asText: hand back the body as it is instead of parsing it as JSON.
    property var fetch: function(url, done, asText) {
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
                done(null, asText ? xhr.responseText : JSON.parse(xhr.responseText))
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

    // The word-timed sources get this long in all; one that hasn't answered by then is a miss.
    property int wordWaitMs: 4000
    // Called when wordWait runs out, for the request still waiting.
    property var giveUp: null

    // BetterLyrics, lrc.red and QQ Music at once; done(lines) with the best answer, or [] for none.
    // A word-timed answer beats a line-timed one, then the order above decides.
    function askWordSources(a, t, len, done) {
        const got = [null, null, null]
        let left = 3
        let over = false
        let settle = null
        settle = () => {
            if (over || (left > 0 && wordWait.running && giveUp === settle))
                return
            over = true
            // A late answer for an older song mustn't stop the wait for the newer one.
            if (giveUp === settle) {
                wordWait.stop()
                giveUp = null
            }
            done(got.find(l => l && l.some(x => x.words)) || got.find(l => l && l.length) || [])
        }
        const answer = (i, lines) => {
            got[i] = lines
            --left
            settle()
        }
        giveUp = settle
        wordWait.restart()
        fetch(L.betterLyricsUrl(a, t, len), (err, r) => answer(0, !err && r ? L.parseTtml(r.ttml) : null))
        fetch(L.qqLyricsUrl(a, t, len), (err, r) => answer(2, !err && r ? L.parseQrc(r.lyrics) : null))
        fetch(L.lrcRedSearchUrl(a, t), (err, r) => {
            const isrc = !err && r ? L.pickLrcRed(r.hits, a, t, len) : ""
            if (!isrc) {
                answer(1, null)
                return
            }
            fetch(L.lrcRedTtmlUrl(isrc), (err2, ttml) => answer(1, !err2 && ttml ? L.parseTtml(ttml) : null), true)
        })
    }

    function load() {
        const k = key
        const a = artist, t = title, al = album, len = lengthUs
        const finish = r => {
            cache.set(k, r)
            if (k === lyrics.key)
                show(r)
        }
        askWordSources(a, t, len, function(lines) {
            if (k !== lyrics.key)
                return
            if (lines.length)
                finish({ state: "synced", lines: lines })
            else
                lrclib(k, a, t, al, len, finish)
        })
    }

    function lrclib(k, a, t, al, len, finish) {
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
    property Timer wordWait: Timer {
        interval: lyrics.wordWaitMs
        onTriggered: if (lyrics.giveUp) lyrics.giveUp()
    }
}
