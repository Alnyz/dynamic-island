import QtQuick
import QtCore
import org.kde.kirigami as Kirigami

Column {
    id: todoRoot
    width: parent.width
    spacing: 10

    Settings {
        id: todoSettings
        category: "TodoList"
        property string tasksJson: "[]"
    }

    ListModel {
        id: todoModel
    }

    function saveTasks() {
        var list = []
        for (var i = 0; i < todoModel.count; i++) {
            var item = todoModel.get(i)
            list.push({ text: item.text, done: item.done })
        }
        todoSettings.tasksJson = JSON.stringify(list)
    }

    function loadTasks() {
        todoModel.clear()
        try {
            var list = JSON.parse(todoSettings.tasksJson)
            for (var i = 0; i < list.length; i++) {
                todoModel.append(list[i])
            }
        } catch(e) {
            console.log("Failed to load tasks:", e)
        }
    }

    Component.onCompleted: loadTasks()

    Row {
        width: parent.width
        height: 32
        spacing: 8

        TextInput {
            id: taskInput
            width: parent.width - 70
            height: 32
            color: "#ffffff"
            padding: 6
            clip: true
            font.pixelSize: 12
            verticalAlignment: TextInput.AlignVCenter

            Rectangle {
                anchors.fill: parent
                color: "#1a1a1a"
                radius: 6
                border.color: "#333333"
                z: -1
            }

            onAccepted: {
                if (text.trim() !== "") {
                    todoModel.append({ text: text.trim(), done: false })
                    saveTasks()
                    text = ""
                }
            }
        }

        Rectangle {
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
                onClicked: {
                    if (taskInput.text.trim() !== "") {
                        todoModel.append({ text: taskInput.text.trim(), done: false })
                        saveTasks()
                        taskInput.text = ""
                    }
                }
            }
        }
    }

    ListView {
        width: parent.width
        height: 180
        model: todoModel
        spacing: 6
        clip: true

        delegate: Row {
            width: parent.width
            height: 28
            spacing: 10

            Rectangle {
                width: 18
                height: 18
                radius: 4
                color: done ? palette.accent : "transparent"
                border.color: palette.accent
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: "#ffffff"
                    font.pixelSize: 11
                    visible: done
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        todoModel.setProperty(index, "done", !done)
                        saveTasks()
                    }
                }
            }

            Text {
                width: parent.width - 18 - 28 - 3 * parent.spacing
                text: model.text
                color: done ? "#8a929c" : "#ffffff"
                font.strikeout: done
                font.pixelSize: 12
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
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
                    onClicked: {
                        todoModel.remove(index)
                        saveTasks()
                    }
                }
            }
        }
    }
}
