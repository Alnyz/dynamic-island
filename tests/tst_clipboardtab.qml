import QtQuick
import QtTest
import "../qml"

Item {
    id: stage
    width: 860
    height: 360

    property var calls: []

    Component {
        id: comp
        ClipboardTab {
            width: 824
            height: 330
            onCopyRequested: id => stage.calls.push("copy " + id)
            onPinRequested: (id, on) => stage.calls.push("pin " + id + " " + on)
            onRemoveRequested: id => stage.calls.push("remove " + id)
            onClearRequested: stage.calls.push("clear")
        }
    }

    TestCase {
        name: "ClipboardTab"
        when: windowShown

        function make(items) {
            stage.calls = []
            const now = Date.now()
            return createTemporaryObject(comp, stage, {
                items: items !== undefined ? items : [
                    { id: "a", kind: "text", text: "Can we move the review to Monday?", pinned: false, time: now - 120000 },
                    { id: "b", kind: "link", text: "https://github.com/x/y", pinned: false, time: now - 540000 },
                    { id: "c", kind: "text", text: "Home address", pinned: true, time: now - 9e6 }
                ]
            })
        }

        function test_pinned_first_and_newest_selected() {
            const t = make()
            compare(findChild(t, "clipHeader-0").text, "Pinned")
            compare(t.selectedId, "a")
            compare(findChild(t, "clipPreview").text, "Can we move the review to Monday?")
            compare(findChild(t, "clipMeta").text, "Text · 33 characters · 2 min ago")
        }

        function test_click_row_previews_it() {
            const t = make()
            mouseClick(findChild(t, "clipRow-b"))
            compare(t.selectedId, "b")
            compare(findChild(t, "clipPreview").text, "https://github.com/x/y")
        }

        function test_actions_send_requests() {
            const t = make()
            mouseClick(findChild(t, "clipCopy"))
            mouseClick(findChild(t, "clipPin"))
            mouseClick(findChild(t, "clipDelete"))
            mouseClick(findChild(t, "clipClear"))
            compare(stage.calls, ["copy a", "pin a true", "remove a", "clear"])
            tryCompare(findChild(t, "clipToast"), "visible", true)
        }

        function test_pinned_item_offers_unpin() {
            const t = make()
            mouseClick(findChild(t, "clipRow-c"))
            compare(findChild(t, "clipPin").text, "Unpin")
            mouseClick(findChild(t, "clipPin"))
            compare(stage.calls, ["pin c false"])
        }

        function test_filter_and_search() {
            const t = make()
            mouseClick(findChild(t, "clipKind-link"))
            compare(t.selectedId, "b")
            compare(findChild(t, "clipRow-a"), null)
            mouseClick(findChild(t, "clipKind-all"))
            t.query = "address"
            compare(t.selectedId, "c")
            compare(findChild(t, "clipRow-a"), null)
        }

        function test_empty() {
            const t = make([])
            compare(findChild(t, "clipEmpty").visible, true)
            compare(findChild(t, "clipCopy").enabled, false)
        }
    }
}
