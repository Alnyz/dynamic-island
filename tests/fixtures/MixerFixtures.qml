import QtQuick 2.15
import "../../qml"

// The objects tst_mixer.qml makes; see the note there on why they live here.
QtObject {
    property var stage

    property Component comp: Component {
        Mixer { width: 824; height: 330 }
    }
}
