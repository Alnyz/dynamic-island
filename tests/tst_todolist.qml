import QtQuick
import QtTest
import "../qml"

Item {
    id: stage
    width: 860
    height: 360

    // A stand-in for TodoStore that records what the tab asked for.
    property var items: []
    property var log: []

    Component {
        id: comp
        TodoList {
            width: 824
            items: stage.items
            addItem: text => { stage.log.push("add:" + text); stage.items = stage.items.concat([{ id: "n" + stage.items.length, text: text, done: false }]) }
            setDone: (id, done) => { stage.log.push("done:" + id + ":" + done); stage.items = stage.items.map(t => t.id === id ? Object.assign({}, t, { done: done }) : t) }
            removeItem: id => { stage.log.push("remove:" + id); stage.items = stage.items.filter(t => t.id !== id) }
            clearDone: () => { stage.log.push("clear"); stage.items = stage.items.filter(t => !t.done) }
        }
    }

    TestCase {
        name: "TodoList"
        when: windowShown

        function make(items) {
            stage.items = items || [{ id: "a", text: "Buy milk", done: false }, { id: "b", text: "Call mum", done: true }]
            stage.log = []
            return createTemporaryObject(comp, stage)
        }

        function test_lists_tasks() {
            const t = make()
            compare(findChild(t, "todoText0").text, "Buy milk")
            compare(findChild(t, "todoText1").font.strikeout, true)
            compare(findChild(t, "todoClearDone").text, "Clear 1 done")
        }

        function test_add_with_enter_and_button() {
            const t = make([])
            const input = findChild(t, "todoInput")
            mouseClick(input)
            keyClick(Qt.Key_A)
            keyClick(Qt.Key_B)
            compare(t.typing, true)
            keyClick(Qt.Key_Return)
            compare(stage.log, ["add:ab"])
            compare(input.text, "")
            input.text = "second"
            mouseClick(findChild(t, "todoAdd"))
            compare(stage.log, ["add:ab", "add:second"])
            // Blank input adds nothing.
            input.text = "   "
            mouseClick(findChild(t, "todoAdd"))
            compare(stage.log.length, 2)
        }

        function test_tick_and_untick() {
            const t = make()
            mouseClick(findChild(t, "todoCheck0"))
            compare(stage.log, ["done:a:true"])
            mouseClick(findChild(t, "todoCheck1"))
            compare(stage.log, ["done:a:true", "done:b:false"])
        }

        function test_delete_and_clear_done() {
            const t = make()
            mouseClick(findChild(t, "todoDelete0"))
            compare(stage.log, ["remove:a"])
            mouseClick(findChild(t, "todoClearDone"))
            compare(stage.log, ["remove:a", "clear"])
            compare(stage.items.length, 0)
            compare(findChild(t, "todoClearDone").visible, false)
        }
    }
}
