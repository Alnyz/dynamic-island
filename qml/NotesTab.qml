import QtQuick
import QtQuick.Controls as QQC
import "logic.js" as L

// Notes from NotesStore (or fakes in tests); saves a moment after typing stops.
Item {
    id: tab

    property var notes: []
    property var readNote: id => ""
    property var writeNote: (id, text) => {}
    property var newId: () => ""
    property var now: () => Date.now()
    property string currentId: ""
    readonly property bool typing: editor.activeFocus

    function flush() {
        if (saveTimer.running) {
            saveTimer.stop()
            writeNote(currentId, editor.text)
        }
    }
    function open(id) {
        flush()
        currentId = id
        editor.text = readNote(id)
    }
    function createNote() {
        flush()
        currentId = newId()
        editor.text = ""
        editor.forceActiveFocus()
    }

    Component.onCompleted: notes.length ? open(notes[0].id) : createNote()
    Component.onDestruction: flush()

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: tab.writeNote(tab.currentId, editor.text)
    }

    Column {
        id: left
        width: 240
        height: parent.height
        spacing: 10

        Item {
            width: parent.width
            height: 16
            Text {
                text: "NOTES"
                color: "#9aa3ad"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
            }
            Text {
                objectName: "noteNew"
                anchors.right: parent.right
                text: "+ New"
                color: newArea.containsMouse ? Qt.lighter(palette.accent, 1.15) : palette.accent
                font.pixelSize: 12
                font.weight: Font.Medium
                MouseArea {
                    id: newArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: tab.createNote()
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: 2
            model: tab.notes
            boundsBehavior: Flickable.StopAtBounds
            QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

            delegate: Rectangle {
                id: note
                required property var modelData
                objectName: "note-" + modelData.id
                width: list.width
                height: 48
                radius: 10
                color: modelData.id === tab.currentId ? "#141414" : noteArea.containsMouse ? "#0f0f0f" : "transparent"
                Column {
                    x: 10
                    width: parent.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        text: note.modelData.title
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: L.noteWhen(note.modelData.modified, tab.now()) + (note.modelData.preview ? " · " + note.modelData.preview : "")
                        color: "#9aa3ad"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: noteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: tab.open(note.modelData.id)
                }
            }
        }
    }

    Column {
        x: left.width + 24
        width: parent.width - x
        height: parent.height
        spacing: 10

        QQC.ScrollView {
            width: parent.width
            height: parent.height - status.height - parent.spacing
            background: Rectangle {
                radius: 14
                color: "#0c0c0c"
                border.color: editor.activeFocus ? "#2f3a48" : "#1c1c1c"
            }
            QQC.TextArea {
                id: editor
                objectName: "noteEditor"
                padding: 16
                wrapMode: TextEdit.Wrap
                color: "#e5e9f0"
                selectionColor: palette.accent
                placeholderText: "Write something…"
                placeholderTextColor: "#8a929c"
                font.pixelSize: 14
                background: null
                onTextChanged: if (activeFocus) saveTimer.restart()
            }
        }

        Item {
            id: status
            width: parent.width
            height: 16
            Text {
                text: "First line is the title"
                color: "#9aa3ad"
                font.pixelSize: 12
            }
            Text {
                objectName: "noteStatus"
                anchors.right: parent.right
                text: saveTimer.running ? "Saving…" : "Saved"
                color: "#9aa3ad"
                font.pixelSize: 12
            }
        }
    }
}
