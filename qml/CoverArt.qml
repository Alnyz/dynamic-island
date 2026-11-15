import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15
import QtGraphicalEffects 1.15
import org.kde.kirigami 2.19 as Kirigami

Rectangle {
    id: art

    property url source
    // Shown when there's no cover, e.g. Spotify sends none during ads.
    property string fallbackIcon

    color: ipal.button

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
    OpacityMask {
        anchors.fill: parent
        source: cover
        maskSource: coverMask
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
