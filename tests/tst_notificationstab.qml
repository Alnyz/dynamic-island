import QtQuick
import QtTest
import "../qml"

Item {
    id: stage
    width: 860
    height: 360

    property var calls: []
    readonly property real now: new Date(2026, 9, 25, 15, 42).getTime()

    Component {
        id: comp
        NotificationsTab {
            width: 820
            height: 300
            now: () => stage.now
            onOpenRequested: (id, entry) => stage.calls.push("open " + id + " " + entry)
            onRemoveRequested: id => stage.calls.push("remove " + id)
            onClearRequested: stage.calls.push("clear")
        }
    }

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
            return createTemporaryObject(comp, stage, { groups: groups !== undefined ? groups : fixture(false), lastSeen: 0 })
        }

        function rows(t) {
            const out = []
            const walk = item => {
                for (const c of item.children) {
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
