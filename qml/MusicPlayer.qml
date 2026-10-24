import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "logic.js" as L

Item {
    id: music

    property var player: null
    readonly property bool playing: player !== null && player.playbackStatus === L.Status.Playing
    readonly property string appIcon: player ? player.iconName || player.desktopEntry || "" : ""
    readonly property color dim: Qt.rgba(1, 1, 1, 0.62)

    implicitHeight: 330

    Text {
        visible: music.player === null
        anchors.centerIn: parent
        text: "Nothing playing"
        color: "#9aa3ad"
        font.pixelSize: 13
    }

    // The cover, blurred and faded to black at the edges, so each song tints the panel.
    Item {
        anchors.fill: parent
        visible: music.player !== null && glowSource.status === Image.Ready

        Image {
            id: glowSource
            anchors.fill: parent
            source: music.player ? music.player.artUrl : ""
            // A few pixels, smoothly stretched, is already a soft colour field; the blur only hides the seams.
            sourceSize: Qt.size(6, 6)
            smooth: true
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: glowSource
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.2
            opacity: 0.4
        }
        Shape {
            width: parent.width
            height: parent.width
            transform: Scale { yScale: music.height / Math.max(1, music.width) }
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: music.width / 2
                    centerY: music.width / 2
                    focalX: centerX
                    focalY: centerY
                    centerRadius: music.width / 2
                    GradientStop { position: 0.1; color: "transparent" }
                    GradientStop { position: 0.8; color: "#000000" }
                }
                PathRectangle { width: music.width; height: music.width }
            }
        }
    }

    Column {
        width: Math.min(720, parent.width - 80)
        anchors.centerIn: parent
        visible: music.player !== null
        spacing: 0

        Row {
            width: parent.width
            spacing: 30

            Item {
                width: 170
                height: 170
                RectangularShadow {
                    anchors.fill: parent
                    offset.y: 14
                    blur: 40
                    radius: 16
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
                CoverArt {
                    anchors.fill: parent
                    radius: 16
                    source: music.player ? music.player.artUrl : ""
                    fallbackIcon: music.appIcon
                }
            }

            Column {
                width: parent.width - 170 - parent.spacing
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    objectName: "title"
                    width: parent.width
                    text: music.player ? music.player.track : ""
                    color: "#ffffff"
                    font.pixelSize: 26
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    topPadding: 6
                    text: music.player ? [music.player.artist, music.player.album].filter(s => s).join(" · ") : ""
                    color: music.dim
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                Item {
                    width: parent.width
                    height: 34 + 28

                    Row {
                        anchors.bottom: parent.bottom
                        height: 34
                        spacing: 10
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            source: "audio-volume-high"
                            color: music.dim
                            isMask: true
                        }
                        VolumeSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 130
                            fill: "#e8e2d0"
                            trackColor: Qt.rgba(1, 1, 1, 0.14)
                            value: music.player ? music.player.volume : 0
                            onMoved: v => music.player.volume = v
                        }
                    }

                    Rectangle {
                        visible: music.player !== null && music.player.canRaise
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: openRow.implicitWidth + 28
                        height: 34
                        radius: height / 2
                        color: openArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.45)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        Row {
                            id: openRow
                            anchors.centerIn: parent
                            spacing: 8
                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 13
                                height: 13
                                source: "external-link-symbolic"
                                color: "#ffffff"
                                isMask: true
                            }
                            Text {
                                text: "Open " + (music.player ? music.player.identity : "")
                                color: "#ffffff"
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: openArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: music.player.Raise()
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 26 }

        VolumeSlider {
            objectName: "progress"
            width: parent.width
            fill: "#e8e2d0"
            trackColor: Qt.rgba(1, 1, 1, 0.14)
            enabled: music.player !== null && music.player.canSeek
            dimmed: !enabled
            value: music.player && music.player.length > 0 ? music.player.position / music.player.length : 0
            onMoved: v => music.player.position = Math.round(v * music.player.length)
        }
        Item {
            width: parent.width
            height: 16
            Text {
                text: music.player ? L.formatTime(music.player.position) : ""
                color: music.dim
                font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right
                text: music.player ? L.formatTime(music.player.length) : ""
                color: music.dim
                font.pixelSize: 11
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 8
            spacing: 22
            ControlButton {
                objectName: "shuffle"
                anchors.verticalCenter: parent.verticalCenter
                visible: music.player !== null && (music.player.shuffle ?? 0) !== L.Shuffle.Unknown
                iconName: "media-playlist-shuffle"
                iconColor: music.player && music.player.shuffle === L.Shuffle.On ? palette.accent : "#6b737c"
                onClicked: music.player.shuffle = music.player.shuffle === L.Shuffle.On ? L.Shuffle.Off : L.Shuffle.On
            }
            ControlButton {
                objectName: "prev"
                anchors.verticalCenter: parent.verticalCenter
                iconName: "media-skip-backward"
                enabled: music.player !== null && music.player.canGoPrevious
                onClicked: music.player.Previous()
            }
            Rectangle {
                objectName: "playPause"
                anchors.verticalCenter: parent.verticalCenter
                width: 54
                height: 54
                radius: 27
                color: playArea.pressed ? "#d8d8d8" : "#ffffff"
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: music.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                    color: "#000000"
                    isMask: true
                }
                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    onClicked: music.player.PlayPause()
                }
            }
            ControlButton {
                objectName: "next"
                anchors.verticalCenter: parent.verticalCenter
                iconName: "media-skip-forward"
                enabled: music.player !== null && music.player.canGoNext
                onClicked: music.player.Next()
            }
            ControlButton {
                objectName: "loop"
                anchors.verticalCenter: parent.verticalCenter
                visible: music.player !== null && (music.player.loopStatus ?? 0) !== L.Loop.Unknown
                iconName: music.player && music.player.loopStatus === L.Loop.Track ? "media-repeat-single" : "media-playlist-repeat"
                iconColor: music.player && music.player.loopStatus > L.Loop.None ? palette.accent : "#6b737c"
                onClicked: music.player.loopStatus = L.nextLoop(music.player.loopStatus)
            }
        }
    }
}
