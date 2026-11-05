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

    // Only made for a real shader: an empty or unknown name would fall back to Qt's default shader,
    // which wants a `source` texture and warns that there is none.
    Loader {
        objectName: "idleShader"
        anchors.fill: parent
        active: art.visible && ["aurora", "wave", "fireflies"].indexOf(art.name) >= 0
        sourceComponent: ShaderEffect {
            property real time: art.time
            property size size: Qt.size(width, height)
            fragmentShader: "qrc:/shaders/" + art.name + ".frag.qsb"
        }
    }

    PixelCat {
        anchors.fill: parent
        visible: art.name === "cat"
        playing: art.playing
    }
}
