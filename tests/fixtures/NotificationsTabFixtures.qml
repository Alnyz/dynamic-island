import QtQuick 2.15
import "../../qml"

// The objects tst_notificationstab.qml makes; see the note there on why they live here.
QtObject {
    property var stage

    property Component comp: Component {
        NotificationsTab {
            width: 820
            height: 300
            now: () => stage.now
            onOpenRequested: (id, entry) => stage.calls.push("open " + id + " " + entry)
            onRemoveRequested: id => stage.calls.push("remove " + id)
            onClearRequested: stage.calls.push("clear")
        }
    }
}
