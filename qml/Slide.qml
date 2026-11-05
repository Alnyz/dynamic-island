import QtQuick

// Content of one of the island's states: fades and slides in when shown, out when not.
Item {
    id: slide
    property bool shown
    anchors.fill: parent
    opacity: shown ? 1 : 0
    visible: opacity > 0
    // Old content leaves fast and the new one fades in after it, so they never overlap visibly.
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: slide.shown ? 90 : 0 }
            NumberAnimation { duration: slide.shown ? 180 : 90 }
        }
    }
    transform: Translate {
        x: slide.shown ? 0 : 12
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }
}
