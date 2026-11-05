import QtQuick
import QtTest
import "../qml"
import "../qml/logic.js" as L

TestCase {
    id: tc
    name: "PlayerSource"

    property real t: 0
    property var requests: []

    Component {
        id: fakeComp
        QtObject {
            property int playbackStatus: L.Status.Playing
            property string track: "Evaluasi"
            property string artist: "Hindia"
            property string artUrl: ""
        }
    }

    Component {
        id: sourceComp
        PlayerSource { now: () => tc.t }
    }

    function makeSource() { return createTemporaryObject(sourceComp, tc) }
    function makeFake(props) { return createTemporaryObject(fakeComp, tc, props || {}) }

    function init() { t = 0 }

    function test_picks_playing() {
        const source = makeSource()
        const fake = makeFake()
        source.players = [fake]
        verify(source.player === fake)
    }

    function test_player_removed_goes_null() {
        const source = makeSource()
        const fake = makeFake()
        source.players = [fake]
        source.players = []
        compare(source.player, null)
    }

    function test_pause_timeout() {
        const source = makeSource()
        const fake = makeFake()
        source.players = [fake]
        t = 1000
        fake.playbackStatus = L.Status.Paused
        t = 1000 + 299000
        source.reevaluate()
        verify(source.player === fake)
        t = 1000 + 300000
        source.reevaluate()
        compare(source.player, null)
    }

    function test_resume_after_timeout() {
        const source = makeSource()
        const fake = makeFake()
        source.players = [fake]
        t = 1000
        fake.playbackStatus = L.Status.Paused
        t = 1000 + 300000
        source.reevaluate()
        compare(source.player, null)
        fake.playbackStatus = L.Status.Playing
        verify(source.player === fake)
    }

    function test_switch_to_newer_playing() {
        const source = makeSource()
        const a = makeFake({ track: "a" })
        const b = makeFake({ track: "b", playbackStatus: L.Status.Paused })
        source.players = [a, b]
        verify(source.player === a)
        t = 50
        b.playbackStatus = L.Status.Playing
        verify(source.player === b)
    }

    function test_first_seen_paused_is_not_shown() {
        const source = makeSource()
        const live = makeFake({ track: "live" })
        source.players = [live]
        t = 1000
        live.playbackStatus = L.Status.Paused
        t = 2000
        const stale = makeFake({ track: "stale", playbackStatus: L.Status.Paused })
        source.players = [live, stale]
        verify(source.player === live)
    }

    // Plasma's browser integration: a skipped-to song often comes without a cover, and a cover can
    // be withdrawn moments after it arrives.
    function test_art_held_through_browser_gaps() {
        const source = makeSource()
        const fake = makeFake({ track: "one", artUrl: "file:///one.jpg" })
        source.players = [fake]
        tryCompare(source, "artUrl", "file:///one.jpg")

        fake.artUrl = ""
        wait(20)
        compare(source.artUrl, "file:///one.jpg")

        fake.track = "two"
        tryCompare(source, "artUrl", "")

        fake.artUrl = "file:///two.jpg"
        tryCompare(source, "artUrl", "file:///two.jpg")
        fake.artUrl = ""
        wait(20)
        compare(source.artUrl, "file:///two.jpg")
    }

    function test_art_cleared_without_player() {
        const source = makeSource()
        const fake = makeFake({ artUrl: "file:///one.jpg" })
        source.players = [fake]
        tryCompare(source, "artUrl", "file:///one.jpg")
        source.players = []
        tryCompare(source, "artUrl", "")
    }

    function lookupSource(results) {
        const source = createTemporaryObject(sourceComp, tc, { coverLookup: true, lookupDelayMs: 10 })
        tc.requests = []
        source.fetch = function(url, done) { tc.requests.push(url); done(null, { results: results }) }
        return source
    }

    function test_lookup_fills_missing_cover() {
        const source = lookupSource([{ artistName: "Hindia", trackName: "Evaluasi", artworkUrl100: "https://x/a/100x100bb.jpg" }])
        source.players = [makeFake()]
        tryCompare(source, "artUrl", "https://x/a/600x600bb.jpg")
        compare(tc.requests.length, 1)
    }

    function test_lookup_waits_for_the_players_own_cover() {
        const source = lookupSource([{ artistName: "Hindia", trackName: "Evaluasi", artworkUrl100: "https://x/a/100x100bb.jpg" }])
        source.lookupDelayMs = 200
        const fake = makeFake()
        source.players = [fake]
        wait(20)
        fake.artUrl = "file:///own.jpg"
        tryCompare(source, "artUrl", "file:///own.jpg")
        wait(300)
        compare(tc.requests.length, 0)
        compare(source.artUrl, "file:///own.jpg")
    }

    function test_players_cover_replaces_looked_up_one() {
        const source = lookupSource([{ artistName: "Hindia", trackName: "Evaluasi", artworkUrl100: "https://x/a/100x100bb.jpg" }])
        const fake = makeFake()
        source.players = [fake]
        tryCompare(source, "artUrl", "https://x/a/600x600bb.jpg")
        fake.artUrl = "file:///own.jpg"
        tryCompare(source, "artUrl", "file:///own.jpg")
    }

    function test_lookup_searched_once_per_song() {
        const source = lookupSource([])
        const fake = makeFake()
        source.players = [fake]
        tryVerify(() => tc.requests.length === 1)
        fake.track = "Other"
        tryVerify(() => tc.requests.length === 2)
        fake.track = "Evaluasi"
        wait(50)
        compare(tc.requests.length, 2)
        compare(source.artUrl, "")
    }

    function test_no_lookup_when_off() {
        const source = lookupSource([{ artistName: "Hindia", trackName: "Evaluasi", artworkUrl100: "https://x/a/100x100bb.jpg" }])
        source.coverLookup = false
        source.players = [makeFake()]
        wait(50)
        compare(tc.requests.length, 0)
        compare(source.artUrl, "")
    }

    function test_pinned_player_wins_until_another_starts() {
        const source = makeSource()
        const a = makeFake({ track: "a", objectName: "brave" })
        const b = makeFake({ track: "b", playbackStatus: L.Status.Paused, objectName: "spotify" })
        const c = makeFake({ track: "c", playbackStatus: L.Status.Paused, objectName: "vlc" })
        source.players = [a, b, c]
        verify(source.player === a)
        source.pin(b)
        verify(source.player === b)
        // The pinned one changing doesn't drop the pin; a keeps playing, still b.
        t = 10
        b.playbackStatus = L.Status.Playing
        verify(source.player === b)
        // Another player starting does.
        t = 20
        c.playbackStatus = L.Status.Playing
        compare(source.pinned, null)
        verify(source.player === c)
    }

    function test_pin_dropped_when_player_leaves() {
        const source = makeSource()
        const a = makeFake({ track: "a", objectName: "brave" })
        const b = makeFake({ track: "b", playbackStatus: L.Status.Paused, objectName: "spotify" })
        source.players = [a, b]
        source.pin(b)
        source.players = [a]
        compare(source.pinned, null)
        verify(source.player === a)
    }

    function test_choices_are_distinct() {
        const source = makeSource()
        const mux = makeFake({ objectName: "brave.instance1" })
        const real = makeFake({ objectName: "brave.instance1" })
        const ctld = makeFake({ objectName: "playerctld" })
        source.players = [mux, real, ctld]
        compare(source.choices.length, 1)
        verify(source.choices[0] === real)
    }
}
