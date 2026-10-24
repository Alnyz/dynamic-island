import QtQuick

// A 2-px pixel cat that paces the pill, sometimes sits down, and blinks.
Item {
    id: cat

    property bool playing: false
    // Chance per step of sitting down for a while.
    property real sitChance: 0.012
    readonly property int pixel: 2
    readonly property int cols: 14
    readonly property int rows: 9
    readonly property var frames: ({
        walk1: [
            ".........#...#",
            "#........#####",
            "#........#.#.#",
            ".#.......#####",
            "..##########..",
            "..##########..",
            "..##########..",
            "..#.#....#.#..",
            ".#...#..#...#."
        ],
        walk2: [
            ".........#...#",
            "#........#####",
            "#........#.#.#",
            ".#.......#####",
            "..##########..",
            "..##########..",
            "..##########..",
            "...#.#..#.#...",
            "...#.#..#.#..."
        ],
        sit: [
            ".........#...#",
            ".........#####",
            ".........#.#.#",
            ".........#####",
            "......#######.",
            ".....########.",
            "#....########.",
            "#....########.",
            ".####.##.##..."
        ],
        blink: [
            ".........#...#",
            ".........#####",
            ".........#####",
            ".........#####",
            "......#######.",
            ".....########.",
            "#....########.",
            "#....########.",
            ".####.##.##..."
        ]
    })

    property string frame: "sit"
    property real catX: (width - cols * pixel) / 2
    property int dir: 1
    property int sitLeft: 0
    property int tick: 0

    onPlayingChanged: if (!playing) frame = "sit"

    function step() {
        tick++
        if (sitLeft > 0) {
            sitLeft--
            frame = sitLeft % 22 < 2 ? "blink" : "sit"
            return
        }
        if (Math.random() < sitChance) {
            sitLeft = 24 + Math.floor(Math.random() * 24)
            frame = "sit"
            return
        }
        const maxX = width - cols * pixel
        catX += dir * pixel
        if (catX <= 0 || catX >= maxX) {
            catX = Math.max(0, Math.min(maxX, catX))
            dir = -dir
        }
        frame = tick % 4 < 2 ? "walk1" : "walk2"
    }

    Timer {
        interval: 125
        repeat: true
        running: cat.playing && cat.visible
        onTriggered: cat.step()
    }

    Item {
        x: cat.catX
        y: (cat.height - cat.rows * cat.pixel) / 2
        width: cat.cols * cat.pixel
        height: cat.rows * cat.pixel
        transform: Scale {
            origin.x: cat.cols * cat.pixel / 2
            xScale: cat.dir
        }

        Repeater {
            model: cat.cols * cat.rows
            delegate: Rectangle {
                required property int index
                x: index % cat.cols * cat.pixel
                y: Math.floor(index / cat.cols) * cat.pixel
                width: cat.pixel
                height: cat.pixel
                color: "#ffffff"
                visible: cat.frames[cat.frame][Math.floor(index / cat.cols)][index % cat.cols] === "#"
            }
        }
    }
}
