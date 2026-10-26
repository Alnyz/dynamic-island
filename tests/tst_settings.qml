import QtQuick
import QtCore
import QtTest
import "../qml"
import "../qml/logic.js" as L

TestCase {
    id: tc
    name: "Settings"
    when: windowShown

    property string file: StandardPaths.writableLocation(StandardPaths.TempLocation) + "/island-settings-test-" + Date.now() + ".conf"

    Component {
        id: prefsComp
        Prefs { location: tc.file }
    }
    Component {
        id: winComp
        // Tall enough that the whole Alerts page fits without scrolling.
        SettingsWindow { page: 2; visible: true; height: 1400 }
    }

    function make() {
        const prefs = createTemporaryObject(prefsComp, tc)
        prefs.history.known = JSON.stringify([{ key: "org.telegram.desktop", name: "Telegram", icon: "", kind: "apps" }])
        prefs.history.off = []
        prefs.history.apps = true
        prefs.history.save = true
        const win = createTemporaryObject(winComp, tc, { prefs: prefs })
        waitForRendering(win.contentItem)
        return { prefs, win }
    }

    function test_app_switch_edits_off_list() {
        const { prefs, win } = make()
        const box = findChild(win.contentItem, "historyApp-org.telegram.desktop")
        verify(box.checked)
        mouseClick(box)
        compare(L.toList(prefs.history.off), ["org.telegram.desktop"])
        verify(!box.checked)
        mouseClick(box)
        compare(L.toList(prefs.history.off), [])
    }

    function test_kind_off_disables_its_apps() {
        const { prefs, win } = make()
        const box = findChild(win.contentItem, "historyApp-org.telegram.desktop")
        verify(box.enabled)
        mouseClick(findChild(win.contentItem, "historyKind-apps"))
        compare(prefs.history.apps, false)
        verify(!box.enabled)
        prefs.history.apps = true
        mouseClick(findChild(win.contentItem, "historySave"))
        compare(prefs.history.save, false)
        verify(!box.enabled)
        verify(!findChild(win.contentItem, "historyKind-apps").enabled)
    }

    function test_urgent_app_switch() {
        const { prefs, win } = make()
        prefs.fullScreen.urgent = []
        prefs.fullScreen.allNotifications = false
        const box = findChild(win.contentItem, "urgentApp-org.telegram.desktop")
        verify(!box.checked)
        mouseClick(box)
        compare(L.toList(prefs.fullScreen.urgent), ["org.telegram.desktop"])
        prefs.fullScreen.allNotifications = true
        verify(!box.enabled)
    }

    function test_keep_for_days() {
        const { prefs, win } = make()
        const box = findChild(win.contentItem, "historyDays")
        compare(box.currentValue, 7)
        prefs.history.days = 30
        compare(box.currentText, "30 days")
    }
}
