import QtQuick 2.15
import QtTest 1.15
import "../qml"
import "../qml/logic.js" as L

TestCase {
    id: tc
    name: "LivePosition"

    // A player like Spotifry: Plasma's copy of its position only changes on a seek.
    Component {
        id: playerComp
        QtObject {
            property int playbackStatus: L.Status.Playing
            property real length: 191000000
            property string track: "Finesse"
            property real position: 4000000
        }
    }
    Component {
        id: clockComp
        LivePosition {}
    }

    // Plasma's copy stays at 4 s; the clock must not fall back to it.
    function test_waking_up_keeps_the_count() {
        const p = createTemporaryObject(playerComp, tc)
        const c = createTemporaryObject(clockComp, tc, { player: p })
        tryVerify(() => c.value >= 4000000)
        c.base = 120000000
        c.at = Date.now()
        c.active = false
        c.active = true
        wait(250)
        verify(c.value >= 120000000)
    }

    function test_pause_and_play_keep_the_count() {
        const p = createTemporaryObject(playerComp, tc)
        const c = createTemporaryObject(clockComp, tc, { player: p })
        tryVerify(() => c.value >= 4000000)
        c.base = 120000000
        c.at = Date.now()
        wait(300)
        p.playbackStatus = L.Status.Paused
        const held = c.value
        verify(held >= 120300000)
        wait(300)
        compare(c.value, held)
        p.playbackStatus = L.Status.Playing
        tryVerify(() => c.value >= held + 250000)
    }

    function test_a_seek_takes_the_players_position() {
        const p = createTemporaryObject(playerComp, tc)
        const c = createTemporaryObject(clockComp, tc, { player: p })
        p.position = 150000000
        tryVerify(() => c.value >= 150000000)
    }

    function test_move_to_after_a_seek() {
        const p = createTemporaryObject(playerComp, tc)
        const c = createTemporaryObject(clockComp, tc, { player: p })
        tryVerify(() => c.value >= 4000000)
        c.moveTo(90000000)
        verify(c.value >= 90000000)
    }

    function test_counts_at_the_players_speed() {
        const c = createTemporaryObject(clockComp, tc, { player: { playbackStatus: L.Status.Playing, length: 0, position: 5000000, rate: 3 } })
        tryVerify(() => c.value >= 5000000)
        const from = c.value
        wait(1000)
        verify(c.value - from >= 2000000, String(c.value - from))
    }

    function test_a_plain_player_counts() {
        const c = createTemporaryObject(clockComp, tc, { player: { playbackStatus: L.Status.Playing, length: 0, position: 5000000 } })
        tryVerify(() => c.value >= 5000000)
    }
}
