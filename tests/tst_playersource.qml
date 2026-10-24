import QtQuick
import QtTest
import "../qml"
import "../qml/logic.js" as L

TestCase {
    id: tc
    name: "PlayerSource"

    property real t: 0

    Component {
        id: fakeComp
        QtObject {
            property int playbackStatus: L.Status.Playing
            property string track: "Evaluasi"
            property string artist: "Hindia"
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
}
