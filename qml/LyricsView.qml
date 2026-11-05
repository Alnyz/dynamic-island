import QtQuick
import "logic.js" as L
import QtQuick.Controls as QQC

// Lyrics from LyricsSource: synced ones follow the song and seek on click; plain ones scroll.
Item {
    id: view

    property string state: "idle"
    property var lines: []
    property string plain: ""
    property real positionMs: 0
    property color tint: "#ffffff"
    signal seekRequested(real ms)

    readonly property int current: state === "synced" ? L.lyricLine(lines, positionMs) : -1

    Text {
        objectName: "lyricsStatus"
        visible: view.state !== "synced" && view.state !== "plain"
        anchors.verticalCenter: parent.verticalCenter
        text: view.state === "loading" ? "Looking for lyrics…"
            : view.state === "instrumental" ? "Instrumental"
            : view.state === "off" ? "Lyrics are off in Settings"
            : "No lyrics found for this song"
        color: "#9aa3ad"
        font.pixelSize: 13
    }

    ListView {
        id: list
        objectName: "lyricsList"
        visible: view.state === "synced"
        anchors.fill: parent
        clip: true
        model: view.state === "synced" ? view.lines : []
        currentIndex: view.current
        interactive: true
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: height / 2 - 12
        preferredHighlightEnd: height / 2 + 12
        highlightMoveDuration: 350
        spacing: 4
        delegate: Text {
            required property var modelData
            required property int index
            objectName: "lyricLine" + index
            width: ListView.view.width
            text: modelData.text || "♪"
            color: index === view.current ? view.tint : index < view.current ? "#6b737c" : "#c4cad1"
            font.pixelSize: index === view.current ? 15 : 13
            font.weight: index === view.current ? Font.DemiBold : Font.Normal
            wrapMode: Text.WordWrap
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
    // One click area over the whole list picks the line under the pointer, also while the list is
    // scrolling to follow the song. The wheel still scrolls the list.
    MouseArea {
        objectName: "lyricsClickArea"
        visible: list.visible
        anchors.fill: list
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            const p = list.contentItem.mapFromItem(this, mouse.x, mouse.y)
            const i = list.indexAt(p.x, p.y)
            if (i >= 0)
                view.seekRequested(view.lines[i].ms)
        }
    }

    QQC.ScrollView {
        visible: view.state === "plain"
        anchors.fill: parent
        Text {
            objectName: "lyricsPlain"
            width: view.width - 12
            text: view.plain
            color: "#c4cad1"
            font.pixelSize: 13
            lineHeight: 1.2
            wrapMode: Text.WordWrap
        }
    }
}
