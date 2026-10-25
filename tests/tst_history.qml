import QtQuick
import QtTest
import "../qml"

TestCase {
    id: tc
    name: "History"

    property real t: 0
    readonly property var telegram: ({ app: "Telegram", desktopEntry: "org.telegram.desktop", icon: "telegram", title: "Rina", body: "hi", replaces: 0 })

    Component {
        id: historyComp
        NotificationHistory { now: () => tc.t }
    }

    SignalSpy { id: editedSpy; signalName: "itemsEdited" }

    function make() {
        const h = createTemporaryObject(historyComp, tc)
        editedSpy.clear()
        editedSpy.target = h
        return h
    }

    function init() { t = 1000 }

    function test_add_saves_and_counts() {
        const h = make()
        h.add(telegram)
        compare(h.items.length, 1)
        compare(h.newCount, 1)
        compare(editedSpy.count, 1)
    }

    function test_blocked_app_not_saved_but_remembered() {
        const h = make()
        h.settings = Object.assign({}, h.settings, { off: ["org.telegram.desktop"] })
        h.add(telegram)
        compare(h.items.length, 0)
        compare(h.apps.length, 1)
        compare(editedSpy.count, 0)
    }

    function test_leave_clears_new() {
        const h = make()
        h.add(telegram)
        t = 2000
        h.leave()
        compare(h.newCount, 0)
        compare(h.lastSeen, 2000)
        t = 3000
        h.add(telegram)
        compare(h.newCount, 1)
    }

    function test_mark_seen_keeps_row() {
        const h = make()
        h.add(telegram)
        h.markSeen(h.items[0].id)
        compare(h.items.length, 1)
        compare(h.newCount, 0)
    }

    function test_remove_and_clear() {
        const h = make()
        h.add(telegram)
        t = 2000
        h.add(telegram)
        h.remove(h.items[0].id)
        compare(h.items.length, 1)
        compare(h.items[0].time, 1000)
        compare(editedSpy.count, 3)
        h.clear()
        compare(h.items.length, 0)
        compare(editedSpy.count, 4)
    }

    function test_save_off_hides_count() {
        const h = make()
        h.add(telegram)
        h.settings = Object.assign({}, h.settings, { save: false })
        compare(h.newCount, 0)
        compare(h.items.length, 1)
    }

    function test_prune_drops_expired() {
        const h = make()
        h.add(telegram)
        t = 1000 + 8 * 86400000
        h.prune()
        compare(h.items.length, 0)
        compare(editedSpy.count, 2)
    }
}
