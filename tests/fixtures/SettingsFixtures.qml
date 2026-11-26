import QtQuick 2.15
import Qt.labs.platform 1.1
import "../../qml"
import "../../qml/logic.js" as L

// The objects tst_settings.qml makes; see the note there on why they live here.
QtObject {
    property var stage

    property Component winComp: Component {
        // Tall enough that the whole Alerts page fits without scrolling.
        SettingsWindow { page: 2; visible: true; height: 1400 }
    }
}
