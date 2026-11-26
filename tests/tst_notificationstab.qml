import QtQuick 2.15
import QtTest 1.15
import "../qml"

Item {
    id: stage

    // Qt 5.15's test collector follows every type a test file names into its source and loops
    // forever on files with inline components, so these are loaded by path instead.
    readonly property var fx: Qt.createComponent(Qt.resolvedUrl("fixtures/NotificationsTabFixtures.qml")).createObject(stage, { stage: stage })

    width: 860
    height: 360

    property var calls: []
    readonly property real now: new Date(2026, 9, 25, 15, 42).getTime()

    TestCase {
        name: "NotificationsTab"
        when: windowShown

        function fixture(seen) {
            const row = (id, key, app, title, ago) => ({ id: id, key: key, app: app, desktopEntry: key, icon: "", title: title, body: "hi there", time: stage.now - ago, seen: seen })
            return [
                { key: "org.telegram.desktop", app: "Telegram", icon: "", rows: [row("t2", "org.telegram.desktop", "Telegram", "Rina", 3 * 60000), row("t1", "org.telegram.desktop", "Telegram", "Budi", 9 * 60000)] },
                { key: "discord", app: "Discord", icon: "", rows: [row("d1", "discord", "Discord", "Rizky", 5 * 60000)] }
            ]
        }

        function make(groups) {
            stage.calls = []
            return createTemporaryObject(fx.comp, stage, { groups: groups !== undefined ? groups : fixture(false), lastSeen: 0 })
        }

        function rows(t) {
            const out = []
            const walk = item => {
                // Qt 5's list properties can't be walked with for...of.
                for (const c of Array.from(item.children)) {
                    if (c.objectName === "notifRow")
                        out.push(c)
                    walk(c)
                }
            }
            walk(t)
            return out
        }

        function test_header() {
            compare(findChild(make(), "notifHeader").text, "3 new")
            compare(findChild(make(fixture(true)), "notifHeader").text, "all seen")
        }

        function test_rows() {
            const t = make()
            const r = rows(t)
            compare(r.length, 3)
            compare(findChild(r[0], "notifTime").text, "3 min")
            compare(findChild(r[0], "notifDot").visible, true)
            compare(findChild(rows(make(fixture(true)))[0], "notifDot").visible, false)
        }

        function test_click_opens() {
            const t = make()
            mouseClick(rows(t)[0])
            compare(stage.calls, ["open t2 org.telegram.desktop"])
        }

        function test_remove() {
            const t = make()
            const r = rows(t)[0]
            mouseMove(r)
            // Qt 5's HoverHandler reacts to the move after the pointer gets there, as a real mouse sends.
            mouseMove(r, r.width / 2 + 1, r.height / 2)
            const x = findChild(r, "notifRemove")
            tryCompare(x, "visible", true)
            mouseClick(x)
            compare(stage.calls, ["remove t2"])
        }

        function test_clear() {
            const t = make()
            mouseClick(findChild(t, "notifClear"))
            compare(stage.calls, ["clear"])
        }

        function test_empty() {
            const t = make([])
            const empty = findChild(t, "notifEmpty")
            compare(empty.visible, true)
            compare(findChild(t, "notifEmptyTitle").text, "No notifications")
            compare(rows(t).length, 0)
        }
    }
}
