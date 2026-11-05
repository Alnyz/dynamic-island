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

    function test_search_finds_and_reveals_a_setting() {
        const { win } = make()
        const field = findChild(win.contentItem, "settingsSearch")
        mouseClick(field)
        keyClick(Qt.Key_L); keyClick(Qt.Key_O); keyClick(Qt.Key_G); keyClick(Qt.Key_I); keyClick(Qt.Key_N)
        compare(win.query, "login")
        const hit = win.results.find(r => r.label === "Start at login")
        verify(hit !== undefined)
        compare(hit.pageTitle, "General")
        const row = findChild(win.contentItem, "searchResult" + win.results.indexOf(hit))
        verify(row)
        mouseClick(row)
        compare(win.page, 8)
        compare(win.query, "")
    }

    function test_search_matches_words_in_any_order_and_page_names() {
        const { win } = make()
        win.query = "brightness volume"
        verify(win.results.some(r => r.pageTitle === "Alerts" && r.label.indexOf("Volume and brightness") === 0))
        // A page's name counts as part of each of its settings.
        win.query = "weather fahrenheit"
        verify(win.results.length > 0)
        verify(win.results.every(r => r.pageTitle === "Weather"))
    }

    function test_search_nothing_matches() {
        const { win } = make()
        win.query = "zzqx"
        compare(win.results.length, 0)
        verify(findChild(win.contentItem, "searchEmpty").visible)
        // One letter isn't a search yet.
        win.query = "a"
        compare(win.results.length, 0)
        verify(!findChild(win.contentItem, "searchEmpty").visible)
    }

    function test_search_enter_opens_first_result() {
        const { win } = make()
        const field = findChild(win.contentItem, "settingsSearch")
        mouseClick(field)
        win.query = "tour"
        verify(win.results.length > 0)
        const first = win.results[0]
        keyClick(Qt.Key_Return)
        compare(win.page, first.page)
    }

    function test_cover_tint_switch() {
        const { prefs, win } = make()
        win.page = 0
        const box = findChild(win.contentItem, "coverTint")
        verify(box.checked)
        mouseClick(box)
        compare(prefs.style.coverTint, false)
    }
}
