import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15
import "logic.js" as L
import QtQuick.Controls 2.15 as QQC

// Lyrics from LyricsSource: synced ones follow the song and seek on click; plain ones scroll.
// Synced lyrics move like Spotifry's lyrics page: the line coming up grows a little before its
// turn, each word lifts and lights as it's sung, lines fade with distance, and the page moves in
// a loose chain, the lines below following one after another.
// ponytail: no blur on far lines (Spotifry has one); it costs a layer per line for little at this size.
Item {
    id: view

    property string state: "idle"
    property var lines: []
    property string plain: ""
    property real positionMs: 0
    property bool playing: false
    signal seekRequested(real ms)

    readonly property bool synced: state === "synced"
    readonly property color ink: ipal.windowText
    // How far below the top the sung line rests, so the line before it still shows above.
    readonly property int restAt: 26

    // The position counted on every frame between updates, so words light on time. It never
    // steps back for a small correction, and never runs more than 0.6 s past the last update.
    property real smoothMs: 0
    property real baseMs: 0
    property real baseAt: 0
    onPositionMsChanged: {
        baseMs = positionMs
        baseAt = Date.now()
        if (!playing || positionMs > smoothMs || smoothMs - positionMs > 300)
            smoothMs = positionMs
    }
    // Qt 5 has no FrameAnimation; a 16 ms timer comes close to every frame.
    Timer {
        interval: 16
        repeat: true
        running: view.playing && view.synced && view.visible
        onTriggered: {
            const next = view.baseMs + Math.min(600, Date.now() - view.baseAt)
            if (next > view.smoothMs || view.smoothMs - next > 300)
                view.smoothMs = next
        }
    }

    readonly property int current: synced ? L.lyricLine(lines, smoothMs) : -1
    readonly property real focusLine: synced ? L.lyricFocus(lines, smoothMs) : -1

    // Reading by hand (the wheel or a drag) stops the page following for 3 seconds.
    property real readingUntil: 0
    property int followed: -1
    signal shifted(int prev, int now, real px)

    onCurrentChanged: {
        if (Date.now() < readingUntil)
            return
        if (L.lyricChains(followed, current))
            chainDelay.restart()
        else
            follow(false)
    }
    onLinesChanged: {
        followed = -1
        Qt.callLater(view.follow, false)
    }
    onVisibleChanged: if (visible) Qt.callLater(view.follow, false)
    onHeightChanged: Qt.callLater(view.follow, false)

    // Moves the page so the sung line rests at restAt; chained, every line starts where it was
    // and travels home after its turn.
    function follow(chain) {
        const row = rows.itemAt(Math.max(0, current))
        if (!row)
            return
        const to = Math.max(0, row.y - restAt)
        const px = to - list.contentY
        list.contentY = to
        shifted(followed, current, chain ? px : 0)
        followed = current
    }
    Timer {
        id: chainDelay
        interval: L.LYRIC_SCROLL_DELAY_MS
        onTriggered: view.follow(true)
    }

    Text {
        objectName: "lyricsStatus"
        visible: !view.synced && view.state !== "plain"
        anchors.verticalCenter: parent.verticalCenter
        text: view.state === "loading" ? "Looking for lyrics…"
            : view.state === "instrumental" ? "Instrumental"
            : view.state === "off" ? "Lyrics are off in Settings"
            : "No lyrics found for this song"
        color: ipal.placeholderText
        font.pixelSize: 13
    }

    FontMetrics {
        id: metrics
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    Flickable {
        id: list
        objectName: "lyricsList"
        visible: view.synced
        anchors.fill: parent
        clip: true
        contentWidth: width
        // Room below the last line, so it too can rest at the top.
        contentHeight: column.height + height
        boundsBehavior: Flickable.StopAtBounds
        onMovementStarted: view.readingUntil = Date.now() + 3000

        Column {
            id: column
            width: list.width
            spacing: 6

            Repeater {
                id: rows
                model: view.synced ? view.lines : []

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    objectName: "lyricLine" + index
                    // Lines from the focus: 0 on it, negative behind it.
                    readonly property real d: index - view.focusLine
                    readonly property bool near: Math.abs(d) < 2
                    // Far lines don't follow the clock, so they don't redraw every frame.
                    readonly property real ms: near ? view.smoothMs : (d > 0 ? -1e12 : 1e12)
                    readonly property bool byWord: !!modelData.words && modelData.words.length > 0
                    width: column.width
                    // The focus line grows without pushing the others, as in Spotifry.
                    height: body.height

                    property real offset: 0
                    transform: Translate { y: row.offset }

                    Connections {
                        target: view
                        function onShifted(prev, now, px) {
                            move.stop()
                            row.offset = px === 0 ? 0 : row.offset + px
                            if (px !== 0) {
                                wait.duration = L.chainDelayMs(row.index, prev, now)
                                move.start()
                            }
                        }
                    }
                    SequentialAnimation {
                        id: move
                        PauseAnimation { id: wait }
                        NumberAnimation {
                            target: row
                            property: "offset"
                            to: 0
                            duration: L.LYRIC_TRAVEL_MS
                            easing.type: Easing.InOutQuad
                        }
                    }

                    Item {
                        id: body
                        width: parent.width * 0.9
                        height: row.byWord ? words.height : whole.height
                        scale: L.focusScale(row.d)
                        transformOrigin: Item.Left

                        // A line without word times lights as a whole.
                        Text {
                            id: whole
                            visible: !row.byWord
                            width: parent.width
                            text: row.modelData.text || "♪"
                            wrapMode: Text.WordWrap
                            font: metrics.font
                            color: view.ink
                            opacity: {
                                const lit = row.ms >= row.modelData.ms ? L.lineLight(row.ms, row.modelData) : 0
                                return L.unlitAlpha(row.d) + (L.litAlpha(row.d) - L.unlitAlpha(row.d)) * lit
                            }
                        }

                        // A line with word times: each word lifts and lights as it's sung.
                        Flow {
                            id: words
                            visible: row.byWord
                            width: parent.width
                            Repeater {
                                model: row.byWord ? row.modelData.words : []
                                delegate: Text {
                                    required property var modelData
                                    readonly property string word: String(modelData.text)
                                    text: word.trim()
                                    // The space after a word, if it has one; syllables of one word sit together.
                                    rightPadding: /\s$/.test(word) ? metrics.advanceWidth(" ") : 0
                                    font: metrics.font
                                    color: view.ink
                                    opacity: {
                                        const un = L.unlitAlpha(row.d)
                                        return un + (L.litAlpha(row.d) - un) * L.wordSweep(row.ms, modelData)
                                    }
                                    transform: Translate { y: -2.5 * L.wordRise(row.ms, modelData) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // One click area over the whole list picks the line under the pointer, also while the page
    // is moving. The wheel still scrolls the list.
    MouseArea {
        objectName: "lyricsClickArea"
        visible: list.visible
        anchors.fill: list
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            const p = column.mapFromItem(this, mouse.x, mouse.y)
            const row = column.childAt(p.x, p.y)
            if (row && row.index !== undefined)
                view.seekRequested(view.lines[row.index].ms)
        }
        onWheel: wheel => {
            view.readingUntil = Date.now() + 3000
            list.contentY = Math.max(0, Math.min(list.contentHeight - list.height, list.contentY - wheel.angleDelta.y / 2))
        }
    }

    QQC.ScrollView {
        visible: view.state === "plain"
        anchors.fill: parent
        Text {
            objectName: "lyricsPlain"
            width: view.width - 12
            text: view.plain
            color: ipal.text
            font.pixelSize: 13
            lineHeight: 1.2
            wrapMode: Text.WordWrap
        }
    }
}
