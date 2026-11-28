import QtQuick 2.15
import QtTest 1.15
import Island 1.0

// The C++ player client against two stand-in players that share a name (as two browsers do) on
// their own bus names, one at double speed. tests/dbus/run.sh starts them on a private bus.
TestCase {
    name: "MprisPlayers"
    when: windowShown
    MprisPlayers { id: mp }
    SignalSpy { id: spyA; signalName: "positionRead" }
    SignalSpy { id: spyB; signalName: "positionRead" }
    SignalSpy { id: rateA; signalName: "rateChanged" }
    property var a: null
    property var b: null
    function initTestCase() {
        tryVerify(() => mp.list.length === 2, 5000)
        for (const p of mp.list) {
            if (p.objectName === "fakeA") a = p
            if (p.objectName === "fakeB") b = p
        }
        tryVerify(() => a.track === "Song" && b.track === "Song", 3000)
        spyA.target = a; spyB.target = b; rateA.target = a
    }
    function test_1_same_name_two_buses() {
        compare(a.identity, "Brave"); compare(b.identity, "Brave")
        compare(a.rate, 2); compare(b.rate, 1)
    }
    function test_2_ask_answers_only_for_itself() {
        spyA.clear(); spyB.clear()
        a.askPosition()
        spyA.wait(2000)
        compare(spyA.signalArguments[0][0], 10000000)
        wait(300)
        compare(spyB.count, 0)
        b.askPosition()
        spyB.wait(2000)
        compare(spyB.signalArguments[0][0], 100000000)
        compare(spyA.count, 1)
    }
    function test_3_counts_at_rate() {
        const p0 = a.position, q0 = b.position
        wait(1000)
        const da = a.position - p0, db = b.position - q0
        verify(Math.abs(da - 2000000) < 250000, "A moved " + da)
        verify(Math.abs(db - 1000000) < 250000, "B moved " + db)
    }
    function test_4_rate_change_keeps_time() {
        const before = a.position
        a.Seek(1)
        tryCompare(a, "rate", 0.5, 2000)
        compare(rateA.count, 1)
        const p0 = a.position
        verify(p0 >= before, "jumped back: " + before + " -> " + p0)
        wait(1000)
        const d = a.position - p0
        verify(Math.abs(d - 500000) < 200000, "moved " + d)
    }
    function test_5_answer_after_song_change_dropped() {
        a.Seek(2)
        wait(200)
        spyA.clear()
        a.askPosition()
        a.Seek(3)
        tryCompare(a, "track", "Another song", 2000)
        wait(800)
        compare(spyA.count, 0)
        // A fresh ask on the new song still answers.
        a.askPosition()
        spyA.wait(2000)
    }
    function test_6_seek_moves_position() {
        a.Seek(4)
        tryVerify(() => Math.abs(a.position - 42000000) < 300000, 2000)
    }
}
