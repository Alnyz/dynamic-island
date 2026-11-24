import QtQuick 2.15
import "../../qml"
import "../../qml/logic.js" as L

// The objects tst_components.qml makes; see the note there on why they live here.
QtObject {
    property var stage

    property Component menuComp: Component {
        PillMenu {}
    }
}
