import QtQuick
import QtTest
import "../qml"

Item {
    id: stage
    width: 860
    height: 360

    property var files: ({})
    property int nextId: 1

    Component {
        id: comp
        NotesTab {
            width: 824
            height: 330
            readNote: id => stage.files[id] || ""
            writeNote: (id, text) => { stage.files[id] = text }
            newId: () => "n" + stage.nextId++
        }
    }

    TestCase {
        name: "NotesTab"
        when: windowShown

        function make(notes) {
            stage.files = { g: "Groceries\n- eggs", w: "Wi-Fi\nsticker" }
            stage.nextId = 1
            return createTemporaryObject(comp, stage, {
                notes: notes !== undefined ? notes : [
                    { id: "g", title: "Groceries", preview: "- eggs", modified: Date.now() },
                    { id: "w", title: "Wi-Fi", preview: "sticker", modified: Date.now() - 864e5 * 3 }
                ]
            })
        }

        function test_opens_newest_note() {
            const t = make()
            compare(t.currentId, "g")
            compare(findChild(t, "noteEditor").text, "Groceries\n- eggs")
        }

        function test_typing_saves_after_a_pause() {
            const t = make()
            const editor = findChild(t, "noteEditor")
            editor.forceActiveFocus()
            editor.cursorPosition = editor.length
            keyClick("s")
            compare(findChild(t, "noteStatus").text, "Saving…")
            tryCompare(stage.files, "g", "Groceries\n- eggss")
            tryCompare(findChild(t, "noteStatus"), "text", "Saved")
        }

        function test_switching_note_saves_first() {
            const t = make()
            const editor = findChild(t, "noteEditor")
            editor.forceActiveFocus()
            editor.cursorPosition = editor.length
            keyClick("x")
            mouseClick(findChild(t, "note-w"))
            compare(stage.files.g, "Groceries\n- eggsx")
            compare(editor.text, "Wi-Fi\nsticker")
        }

        function test_new_note() {
            const t = make()
            mouseClick(findChild(t, "noteNew"))
            compare(t.currentId, "n1")
            compare(findChild(t, "noteEditor").text, "")
        }

        function test_no_notes_starts_blank() {
            const t = make([])
            compare(t.currentId, "n1")
            compare(findChild(t, "noteEditor").text, "")
        }
    }
}
