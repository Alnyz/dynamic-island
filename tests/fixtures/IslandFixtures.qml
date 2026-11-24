import QtQuick 2.15
import "../../qml"
import "../../qml/logic.js" as L

// The objects tst_island.qml makes; see the note there on why they live here.
QtObject {
    property var stage

    property Component centeredComp: Component {
        Item {
            width: 0
            property alias island: isl
            Island { id: isl; anchors.horizontalCenter: parent.horizontalCenter; systemControls: false }
        }
    }

    property Component islandComp: Component {
        Island { x: 100; y: 20; systemControls: false }
    }
}
