import QtQuick
import "logic.js" as L

Column {
    id: card

    property var player: null
    readonly property bool playing: player !== null && player.playbackStatus === L.Status.Playing
    readonly property bool hasLength: player !== null && player.length > 0

    spacing: 10

    Row {
        width: parent.width
        spacing: 12
        CoverArt {
            width: 56
            height: 56
            radius: 10
            source: card.player ? card.player.artUrl : ""
            fallbackIcon: card.player ? card.player.iconName || card.player.desktopEntry || "" : ""
        }
        Column {
            width: parent.width - 68
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: card.player ? card.player.track : "Nothing playing"
                color: card.player ? "#ffffff" : "#9aa3ad"
                font.pixelSize: 14
                font.weight: card.player ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: card.player !== null
                text: card.player ? card.player.artist : ""
                color: "#9aa3ad"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    Column {
        visible: card.hasLength
        width: parent.width
        spacing: 4
        Rectangle {
            width: parent.width
            height: 3
            radius: 1.5
            color: "#262626"
            Rectangle {
                width: card.hasLength ? parent.width * Math.min(1, card.player.position / card.player.length) : 0
                height: parent.height
                radius: parent.radius
                color: "#ffffff"
            }
        }
        Item {
            width: parent.width
            height: elapsed.implicitHeight
            Text {
                id: elapsed
                text: card.hasLength ? L.formatTime(card.player.position) : ""
                color: "#9aa3ad"
                font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.right: parent.right
                text: card.hasLength ? L.formatTime(card.player.length) : ""
                color: "#9aa3ad"
                font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
        }
    }

    Row {
        visible: card.player !== null
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 20
        ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "media-skip-backward"
            iconSize: 16
            enabled: card.player !== null && card.player.canGoPrevious
            onClicked: card.player.Previous()
        }
        Rectangle {
            width: 38
            height: 38
            radius: 19
            color: "#ffffff"
            ControlButton {
                anchors.centerIn: parent
                iconName: card.playing ? "media-playback-pause" : "media-playback-start"
                iconSize: 18
                iconColor: "#000000"
                onClicked: card.player.PlayPause()
            }
        }
        ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "media-skip-forward"
            iconSize: 16
            enabled: card.player !== null && card.player.canGoNext
            onClicked: card.player.Next()
        }
    }
}
