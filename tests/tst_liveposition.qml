import QtQuick
import QtTest
import "../qml"
import "../qml/logic.js" as L

TestCase {
    id: tc
    name: "LivePosition"

    // A player like Spotifry: its position is only right when asked for.
    Component {
        id: playerComp
        QtObject {
            property int playbackStatus: L.Status.Playing
            property real length: 191000000
            property string track: "Finesse"
            property real position: 4000000
            property real real: 121000000
            property int asked: 0
            function updatePosition() {
                asked++
                position = real
            }
        }
    }
    Component {
        id: clockComp
        LivePosition {}
    }

    function test_a_new_clock_asks_the_player() {
        const p = createTemporaryObject(playerComp, tc)
        const c = createTemporaryObject(clockComp, tc, { player: p })
        tryVerify(() => c.value >= 121000000)
        verify(p.asked > 0)
    }

    function test_waking_up_asks_again() {
        const p = createTemporaryObject(playerComp, tc)
        const c = createTemporaryObject(clockComp, tc, { player: p, active: false })
        tryVerify(() => p.asked > 0)
        const before = p.asked
        p.real = 150000000
        c.active = true
        tryVerify(() => p.asked > before)
        tryVerify(() => c.value >= 150000000)
    }

    function test_players_without_the_call_still_count() {
        const c = createTemporaryObject(clockComp, tc, { player: { playbackStatus: L.Status.Playing, length: 0, position: 5000000 } })
        tryVerify(() => c.value >= 5000000)
    }
}
