import QtQuick
import org.kde.kirigami as Kirigami

// The To-Do tab. The list and its changes come from outside (TodoStore in the app).
Column {
    id: todo

    // [{id, text, done}]
    property var items: []
    property var addItem: text => {}
    property var setDone: (id, done) => {}
    property var removeItem: id => {}
    property var clearDone: () => {}
    // Typing a task keeps the panel open with the pointer elsewhere.
    readonly property bool typing: taskInput.activeFocus && taskInput.text !== ""
    readonly property int doneCount: items.filter(t => t.done).length

    spacing: 10

    function submit() {
        if (taskInput.text.trim() === "")
            return
        todo.addItem(taskInput.text)
        taskInput.text = ""
    }

    Row {
        width: parent.width
        height: 32
        spacing: 8

        TextInput {
            id: taskInput
            objectName: "todoInput"
            width: parent.width - 70
            height: 32
            color: "#ffffff"
            leftPadding: 10
            rightPadding: 10
            clip: true
            font.pixelSize: 12
            verticalAlignment: TextInput.AlignVCenter
            onAccepted: todo.submit()

            Rectangle {
                anchors.fill: parent
                color: "#1a1a1a"
                radius: 6
                border.color: taskInput.activeFocus ? palette.accent : "#333333"
                z: -1
            }
            Text {
                visible: taskInput.text === ""
                anchors.verticalCenter: parent.verticalCenter
                x: 10
                text: "Add a task"
                color: "#6b737d"
                font.pixelSize: 12
            }
        }

        Rectangle {
            objectName: "todoAdd"
            width: 62
            height: 32
            radius: 6
            color: palette.accent

            Text {
                anchors.centerIn: parent
                text: "Add"
                color: "#ffffff"
                font.bold: true
                font.pixelSize: 12
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: todo.submit()
            }
        }
    }

    Text {
        visible: todo.items.length === 0
        text: "Nothing to do. Add a task above; the next one shows on the idle pill."
        color: "#9aa3ad"
        font.pixelSize: 12
    }

    ListView {
        objectName: "todoList"
        width: parent.width
        height: Math.min(contentHeight, 220)
        model: todo.items
        spacing: 6
        clip: true

        delegate: Row {
            id: row
            required property var modelData
            required property int index
            objectName: "todoRow" + index
            width: ListView.view.width
            height: 28
            spacing: 10

            Rectangle {
                objectName: "todoCheck" + row.index
                width: 18
                height: 18
                radius: 4
                color: row.modelData.done ? palette.accent : "transparent"
                border.color: palette.accent
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: "#ffffff"
                    font.pixelSize: 11
                    visible: row.modelData.done
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: todo.setDone(row.modelData.id, !row.modelData.done)
                }
            }

            Text {
                objectName: "todoText" + row.index
                width: parent.width - 18 - 24 - 2 * parent.spacing
                text: row.modelData.text
                color: row.modelData.done ? "#8a929c" : "#ffffff"
                font.strikeout: row.modelData.done
                font.pixelSize: 12
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                objectName: "todoDelete" + row.index
                width: 24
                height: 24
                radius: 12
                color: deleteArea.containsMouse ? "#3a1d1d" : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: deleteArea.containsMouse ? "#ff8a8a" : "#8a929c"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: deleteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: todo.removeItem(row.modelData.id)
                }
            }
        }
    }

    Text {
        objectName: "todoClearDone"
        visible: todo.doneCount > 0
        text: "Clear " + todo.doneCount + " done"
        color: clearArea.containsMouse ? "#ffffff" : "#9aa3ad"
        font.pixelSize: 12
        MouseArea {
            id: clearArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: todo.clearDone()
        }
    }
}
