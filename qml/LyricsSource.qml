import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15
import "logic.js" as L

// Lyrics for the current song, only while something shows them. Word-timed ones from
// BetterLyrics, lrc.red and QQ Music (through BetterLyrics) are asked together; LRCLIB, timed by
// line, only when none of them has the song. Sends the artist, title, album and length; nothing else.
QtObject {
    id: lyrics

    property bool enabled: false
    // Set by the lyrics view while it's on screen; no request is made otherwise.
    property bool wanted: false
    // Set by the pill while it shows the current line in place of the title.
    property bool wantedPill: false
    // Keys of the sources turned off (L.lyricSources).
    property var off: []
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
    // The sources in use are part of the key, so turning one off or on asks again.
    readonly property string key: artist + "\n" + title + "\n" + Math.round(lengthUs / 1e6) + "\n" + off.join(",")

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

    // The song the latest request is for, while it runs.
    property string asking: ""
    property int serial: 0
    // An answer a source failed to contribute to: kept for this song only, so it's asked again
    // the next time the song comes round.
    property var partial: null

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
        if (partial && partial.key === key) {
            show(partial.result)
            return
        }
        // Already on its way; the pill asks again each time the pointer leaves it.
        if (asking === key) {
            show({ state: "loading" })
            return
        }
        // Read straight from the two flags: a derived property can still hold its old value
        // in the change handler that brought us here.
        const asked = wanted || wantedPill
        show({ state: asked ? "loading" : "idle" })
        if (asked)
            timer.restart()
    }

    // The word-timed sources get this long in all; one that hasn't answered by then is a miss.
    property int wordWaitMs: 4000
    // Called when wordWait runs out, for the request still waiting.
    property var giveUp: null

    // BetterLyrics, lrc.red and QQ Music at once; done(lines, failed) with the best answer, or [] for
    // none. failed: a source errored or didn't answer in time.
    // A word-timed answer beats a line-timed one, then the order above decides.
    function askWordSources(a, t, len, done) {
        const got = [null, null, null]
        let left = 3
        let over = false
        let failed = false
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
            done(got.find(l => l && l.some(x => x.words)) || got.find(l => l && l.length) || [], failed || left > 0)
        }
        const answer = (i, lines, err) => {
            failed = failed || !!err
            got[i] = lines
            --left
            settle()
        }
        giveUp = settle
        wordWait.restart()
        const skip = off.slice()
        if (skip.includes("betterlyrics"))
            answer(0, null)
        else
            fetch(L.betterLyricsUrl(a, t, len), (err, r) => answer(0, !err && r ? L.parseTtml(r.ttml) : null, err))
        if (skip.includes("qq"))
            answer(2, null)
        else
            fetch(L.qqLyricsUrl(a, t, len), (err, r) => answer(2, !err && r ? L.parseQrc(r.lyrics) : null, err))
        if (skip.includes("lrcred"))
            answer(1, null)
        else
            fetch(L.lrcRedSearchUrl(a, t), (err, r) => {
                const isrc = !err && r ? L.pickLrcRed(r.hits, a, t, len) : ""
                if (!isrc) {
                    answer(1, null, err)
                    return
                }
                fetch(L.lrcRedTtmlUrl(isrc), (err2, ttml) => answer(1, !err2 && ttml ? L.parseTtml(ttml) : null, err2), true)
            })
    }

    function load() {
        const k = key
        const n = ++serial
        asking = k
        const a = artist, t = title, al = album, len = lengthUs
        // True once the answer is no use: a newer request took over, or the song or setting changed.
        const stale = () => {
            if (n !== serial)
                return true
            if (k === lyrics.key && enabled)
                return false
            asking = ""
            return true
        }
        askWordSources(a, t, len, function(lines, failed) {
            if (stale())
                return
            const finish = r => {
                asking = ""
                // A word-timed answer can't be bettered; anything else might be, once the failed source is back.
                if (!failed || (r.lines && r.lines.some(x => x.words)))
                    cache.set(k, r)
                else if (r.state !== "none")
                    partial = { key: k, result: r }
                show(r)
            }
            if (lines.length)
                finish({ state: "synced", lines: lines })
            else if (off.includes("lrclib"))
                finish({ state: "none" })
            else
                lrclib(stale, a, t, al, len, finish)
        })
    }

    function lrclib(stale, a, t, al, len, finish) {
        fetch(L.lyricsGetUrl(a, t, al, len), function(err, record) {
            if (stale())
                return
            if (!err && record) {
                finish(fromRecord(record))
                return
            }
            fetch(L.lyricsSearchUrl(a, t), function(err2, list) {
                if (stale())
                    return
                // A network failure isn't remembered, so it's tried again next time.
                if (err2) {
                    asking = ""
                    show({ state: "none" })
                    return
                }
                finish(fromRecord(L.pickLyrics(Array.isArray(list) ? list : [], a, t, len)))
            })
        })
    }

    onKeyChanged: {
        if (partial && partial.key !== key)
            partial = null
        refresh()
    }
    onEnabledChanged: refresh()
    onWantedChanged: refresh()
    onWantedPillChanged: refresh()

    property Timer timer: Timer {
        interval: lyrics.delayMs
        onTriggered: lyrics.load()
    }
    property Timer wordWait: Timer {
        interval: lyrics.wordWaitMs
        onTriggered: if (lyrics.giveUp) lyrics.giveUp()
    }
}
