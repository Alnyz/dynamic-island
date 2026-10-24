import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Rectangle {
    id: art

    property url source
    // Shown when there's no cover, e.g. Spotify sends none during ads.
    property string fallbackIcon

    color: "#2a2a2a"

    Image {
        id: cover
        anchors.fill: parent
        source: art.source
        fillMode: Image.PreserveAspectCrop
        // Covers arrive at 640px; decode small and mipmap so the 18px pill icon isn't jagged.
        sourceSize: Qt.size(128, 128)
        mipmap: true
        asynchronous: true
        visible: false
    }
    Rectangle {
        id: coverMask
        anchors.fill: parent
        radius: art.radius
        layer.enabled: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: cover
        maskEnabled: true
        maskSource: coverMask
        // Soft mask edge; without it the anti-aliased corners turn solid and the icon looks square.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        visible: cover.status === Image.Ready
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.55)
        height: width
        source: art.fallbackIcon
        visible: art.fallbackIcon !== "" && cover.status !== Image.Ready
    }
}
