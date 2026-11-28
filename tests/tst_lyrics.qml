import QtQuick 2.15
import QtTest 1.15
import "../qml"

TestCase {
    id: tc
    name: "Lyrics"

    property var requests: []
    // url substring -> [err, data]
    property var answers: ({})

    Component {
        id: comp
        LyricsSource {
            enabled: true
            delayMs: 10
            artist: "Maroon 5"
            title: "Girls Like You"
            album: ""
            lengthUs: 235000000
            fetch: function(url, done, asText) {
                tc.requests.push(url)
                for (const k in tc.answers)
                    if (url.indexOf(k) >= 0) {
                        const a = tc.answers[k]
                        done(a[0], a[1])
                        return
                    }
                done(null, null)
            }
        }
    }

    // Only the LRCLIB requests, which come after the word-timed sources.
    function lrclibRequests() {
        return requests.filter(u => u.indexOf("lrclib.net") >= 0)
    }

    function make() {
        requests = []
        return createTemporaryObject(comp, tc)
    }

    function test_nothing_sent_unless_shown() {
        answers = {}
        const l = make()
        wait(50)
        compare(requests.length, 0)
        compare(l.state, "idle")
    }

    function test_synced_from_exact_lookup() {
        answers = { "/api/get": [null, { syncedLyrics: "[00:06.94]Spent 24 hours\n[00:14.21]You spent the weekend", plainLyrics: "x" }] }
        const l = make()
        l.wanted = true
        compare(l.state, "loading")
        tryCompare(l, "state", "synced")
        compare(l.lines.length, 2)
        compare(l.lines[0].text, "Spent 24 hours")
        compare(lrclibRequests().length, 1)
        verify(lrclibRequests()[0].indexOf("duration=235") > 0)
    }

    function test_falls_back_to_search() {
        answers = { "/api/search": [null, [{ artistName: "Maroon 5", trackName: "Girls Like You", duration: 236, plainLyrics: "Spent 24 hours" }]] }
        const l = make()
        l.wanted = true
        tryCompare(l, "state", "plain")
        compare(l.plain, "Spent 24 hours")
        compare(lrclibRequests().length, 2)
    }

    function test_none_found_is_cached() {
        answers = { "/api/search": [null, []] }
        const l = make()
        l.wanted = true
        tryCompare(l, "state", "none")
        l.wanted = false
        l.wanted = true
        compare(l.state, "none")
        wait(50)
        compare(lrclibRequests().length, 2)
    }

    function test_network_failure_not_cached() {
        answers = { "/api/get": ["HTTP 500", null], "/api/search": ["HTTP 500", null] }
        const l = make()
        l.wanted = true
        tryCompare(l, "state", "none")
        answers = { "/api/get": [null, { instrumental: true }] }
        l.wanted = false
        l.wanted = true
        tryCompare(l, "state", "instrumental")
    }

    function test_skipping_quickly_sends_only_the_last_song() {
        answers = { "/api/get": [null, { plainLyrics: "x" }] }
        const l = make()
        l.delayMs = 100
        l.wanted = true
        l.title = "One"
        l.title = "Two"
        l.title = "Three"
        tryCompare(l, "state", "plain")
        compare(lrclibRequests().length, 1)
        verify(lrclibRequests()[0].indexOf("track_name=Three") > 0)
        // The word-timed sources are asked for the last song only, too.
        compare(requests.filter(u => u.indexOf("getLyrics") >= 0).length, 2)
        verify(requests.every(u => u.indexOf("One") < 0 && u.indexOf("Two") < 0))
    }

    readonly property string ttml: '<tt><body><div><p begin="6.94" end="9.0"><span begin="6.94" end="7.5">Spent</span> <span begin="7.5" end="8.0">24</span> <span begin="8.0" end="9.0">hours</span></p></div></body></tt>'

    function test_word_timed_beats_lrclib() {
        answers = { "/getLyrics": [null, { ttml: ttml }], "/api/get": [null, { syncedLyrics: "[00:06.94]Spent 24 hours" }] }
        const l = make()
        l.wanted = true
        tryCompare(l, "state", "synced")
        compare(l.lines[0].words.length, 3)
        compare(l.lines[0].text, "Spent 24 hours")
        compare(lrclibRequests().length, 0)
    }

    function test_lrc_red_by_recording_code() {
        answers = {
            "lrc.red/search": [null, { hits: [{ isrc: "USUM71800001", title: "Girls Like You", artist: "Maroon 5", duration: 235.2 }] }],
            "lrc.red/s/USUM71800001.ttml": [null, ttml]
        }
        const l = make()
        l.wanted = true
        tryCompare(l, "state", "synced")
        compare(l.lines[0].words[2].text, "hours")
    }

    function test_sources_turned_off_are_not_asked() {
        answers = { "/getLyrics": [null, { ttml: ttml }], "/api/get": [null, { syncedLyrics: "[00:06.94]Spent 24 hours" }] }
        const l = make()
        l.off = ["betterlyrics", "qq", "lrcred"]
        l.wanted = true
        tryCompare(l, "state", "synced")
        verify(!l.lines[0].words)
        compare(requests.filter(u => u.indexOf("lrclib.net") < 0).length, 0)
    }

    function test_all_sources_off_finds_nothing() {
        answers = { "/api/get": [null, { syncedLyrics: "[00:06.94]Spent 24 hours" }] }
        const l = make()
        l.off = ["betterlyrics", "qq", "lrcred", "lrclib"]
        l.wanted = true
        tryCompare(l, "state", "none")
        compare(requests.length, 0)
        // Turning one back on asks again.
        l.off = ["betterlyrics", "qq", "lrcred"]
        tryCompare(l, "state", "synced")
    }

    function test_slow_word_source_gives_way_to_lrclib() {
        answers = { "/api/get": [null, { syncedLyrics: "[00:06.94]Spent 24 hours" }] }
        const l = createTemporaryObject(slowComp, tc)
        l.wanted = true
        tryCompare(l, "state", "synced")
        verify(!l.lines[0].words)
    }

    Component {
        id: slowComp
        LyricsSource {
            enabled: true
            delayMs: 10
            wordWaitMs: 100
            artist: "Maroon 5"
            title: "Girls Like You"
            lengthUs: 235000000
            // The word-timed sources never answer; LRCLIB does.
            fetch: function(url, done) {
                if (url.indexOf("lrclib.net/api/get") >= 0)
                    done(null, { syncedLyrics: "[00:06.94]Spent 24 hours" })
            }
        }
    }

    // Answers only when the test says so.
    property var pending: []
    Component {
        id: heldComp
        LyricsSource {
            enabled: true
            delayMs: 10
            artist: "Maroon 5"
            title: "Girls Like You"
            lengthUs: 235000000
            fetch: function(url, done) { tc.pending.push({ url: url, done: done }) }
        }
    }

    function test_hovering_while_loading_asks_once() {
        pending = []
        const l = createTemporaryObject(heldComp, tc)
        l.wanted = true
        tryVerify(() => pending.length === 3)
        l.wanted = false
        l.wanted = true
        compare(l.state, "loading")
        wait(50)
        compare(pending.length, 3)
        pending[0].done(null, { ttml: ttml })
        pending[1].done(null, null)
        pending[2].done(null, null)
        tryCompare(l, "state", "synced")
        compare(l.lines[0].words.length, 3)
    }

    function test_coming_back_to_a_song_waits_for_its_new_request() {
        pending = []
        const l = createTemporaryObject(heldComp, tc)
        l.wanted = true
        tryVerify(() => pending.length === 3)
        l.title = "Other"
        tryVerify(() => pending.length === 6)
        l.title = "Girls Like You"
        tryVerify(() => pending.length === 9)
        // The first request is out of date: one early miss must not settle anything.
        pending[0].done(null, null)
        compare(pending.length, 9)
        compare(l.state, "loading")
    }

    function test_a_result_missing_a_source_is_asked_again_next_time() {
        answers = { "/getLyrics": ["HTTP 500", null], "/api/get": [null, { syncedLyrics: "[00:06.94]Spent 24 hours" }] }
        const l = make()
        l.wanted = true
        tryCompare(l, "state", "synced")
        const sent = requests.length
        // The same song keeps showing it without asking again.
        l.wanted = false
        l.wanted = true
        compare(l.state, "synced")
        wait(50)
        compare(requests.length, sent)
        l.title = "Other"
        l.title = "Girls Like You"
        tryVerify(() => requests.length > sent)
    }

    function test_nothing_found_while_offline_is_not_remembered() {
        answers = { "/getLyrics": ["HTTP 0", null], "lrc.red": ["HTTP 0", null] }
        const l = make()
        l.off = ["lrclib"]
        l.wanted = true
        tryCompare(l, "state", "none")
        answers = { "/getLyrics": [null, { ttml: ttml }] }
        l.wanted = false
        l.wanted = true
        tryCompare(l, "state", "synced")
    }

    function test_off() {
        const l = make()
        l.enabled = false
        l.wanted = true
        compare(l.state, "off")
        wait(50)
        compare(requests.length, 0)
    }
}
