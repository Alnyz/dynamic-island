import QtQuick

// The built-in idle animations: "aurora", "wave", "fireflies" or "cat".
Item {
    id: art

    property string name
    property bool playing: false
    property real time: 0

    // 30 fps instead of the screen's rate: the shaders drift slowly, so it looks the same at half the cost.
    Timer {
        interval: 33
        repeat: true
        running: art.playing && art.visible && art.name !== "cat"
        onTriggered: art.time += interval / 1000
    }

    ShaderEffect {
        anchors.fill: parent
        visible: art.name !== "cat"
        property real time: art.time
        property size size: Qt.size(width, height)
        fragmentShader: visible ? "qrc:/shaders/" + art.name + ".frag.qsb" : ""
    }

    PixelCat {
        anchors.fill: parent
        visible: art.name === "cat"
        playing: art.playing
    }
}
