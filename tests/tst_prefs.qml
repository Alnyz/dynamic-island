import QtQuick
import QtCore
import QtTest
import "../qml"
import "../qml/logic.js" as L

TestCase {
    id: tc
    name: "Prefs"

    property string file: StandardPaths.writableLocation(StandardPaths.TempLocation) + "/island-prefs-test-" + Date.now() + ".conf"

    Component {
        id: prefsComp
        Prefs { location: tc.file }
    }

    function test_values_survive_restart() {
        const a = createTemporaryObject(prefsComp, tc)
        a.shape.height = 36
        a.calendar.icsUrls = ["https://a.example/x.ics", "https://b.example/y.ics"]
        a.quickButtons.hidden = ["lock"]
        // Settings writes changes to the file after a short delay.
        wait(700)
        const b = createTemporaryObject(prefsComp, tc)
        compare(b.shape.height, 36)
        compare(L.toList(b.calendar.icsUrls), ["https://a.example/x.ics", "https://b.example/y.ics"])
        compare(L.toList(b.quickButtons.hidden), ["lock"])
    }

    function test_full_screen_defaults() {
        const p = createTemporaryObject(prefsComp, tc, { location: tc.file + "-fs" })
        verify(p.fullScreen.levels)
        verify(p.fullScreen.jobs)
        verify(p.fullScreen.privacy)
        verify(p.fullScreen.devices)
        verify(p.fullScreen.power)
        verify(!p.fullScreen.allNotifications)
        compare(L.toList(p.fullScreen.urgent), [])
    }

    function test_reset_keeps_calendars() {
        const p = createTemporaryObject(prefsComp, tc)
        p.calendar.icsUrls = ["https://a.example/x.ics"]
        p.shape.idleWidth = 220
        p.behaviour.openOnHover = true
        p.reset()
        compare(p.shape.idleWidth, 180)
        compare(p.behaviour.openOnHover, false)
        compare(L.toList(p.calendar.icsUrls), ["https://a.example/x.ics"])
    }
}
