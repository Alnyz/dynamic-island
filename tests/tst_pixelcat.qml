import QtQuick
import QtTest
import "../qml"

Item {
    id: stage
    width: 200
    height: 32

    Component {
        id: comp
        PixelCat { width: 180; height: 32 }
    }

    TestCase {
        name: "PixelCat"
        when: windowShown

        function test_frames_are_rectangular() {
            const cat = createTemporaryObject(comp, stage)
            for (const name in cat.frames) {
                compare(cat.frames[name].length, cat.rows, name)
                for (const row of cat.frames[name])
                    compare(row.length, cat.cols, name + ": " + row)
            }
        }

        function test_sits_still_when_paused() {
            const cat = createTemporaryObject(comp, stage, { playing: false })
            const x = cat.catX
            wait(400)
            compare(cat.catX, x)
            compare(cat.frame, "sit")
        }

        function test_walks_when_playing() {
            const cat = createTemporaryObject(comp, stage, { playing: true, sitChance: 0 })
            const x = cat.catX
            tryVerify(() => cat.catX !== x, 1000)
            verify(cat.catX >= 0 && cat.catX <= cat.width - cat.cols * cat.pixel)
        }
    }
}
