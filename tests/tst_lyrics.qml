import QtQuick
import QtTest
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
            fetch: function(url, done) {
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
        compare(requests.length, 1)
        verify(requests[0].indexOf("duration=235") > 0)
    }

    function test_falls_back_to_search() {
        answers = { "/api/search": [null, [{ artistName: "Maroon 5", trackName: "Girls Like You", duration: 236, plainLyrics: "Spent 24 hours" }]] }
        const l = make()
        l.wanted = true
        tryCompare(l, "state", "plain")
        compare(l.plain, "Spent 24 hours")
        compare(requests.length, 2)
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
        compare(requests.length, 2)
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
        compare(requests.length, 1)
        verify(requests[0].indexOf("track_name=Three") > 0)
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
