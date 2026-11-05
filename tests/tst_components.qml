import QtQuick
import QtTest
import "../qml"
import "../qml/logic.js" as L

// The parts split out of Island.qml, each on its own with a stand-in for the island.
Item {
    id: stage
    width: 600
    height: 300

    Component {
        id: slideComp
        Slide { width: 200; height: 40 }
    }

    // Just what the parts read from the island.
    Component {
        id: islandFake
        Item {
            id: fake
            width: 330
            height: 60
            property string mode: "peek"
            property var player: ({ position: 50000000, length: 200000000, canSeek: true })
            property bool coverTinted: false
            property color coverTint: "transparent"
            property int tourStep: 0
            property var menuRows: L.pillMenu({ dnd: false, hidden: false })
            property var picked: []
            property int nextCalls: 0
            property int skipCalls: 0
            function pickMenu(key, minutes) { picked.push(key + (minutes ? ":" + minutes : "")) }
            function nextTourStep() { nextCalls++ }
            function skipTour() { skipCalls++ }
        }
    }
    Component {
        id: seekComp
        PeekSeekBar { width: 300; height: 10 }
    }
    Component {
        id: tourComp
        TourCard {}
    }
    Component {
        id: menuComp
        PillMenu {}
    }

    TestCase {
        name: "Components"
        when: windowShown

        function test_slide_shows_and_hides() {
            const s = createTemporaryObject(slideComp, stage, { shown: false })
            compare(s.visible, false)
            s.shown = true
            tryCompare(s, "opacity", 1)
            verify(s.visible)
            s.shown = false
            tryCompare(s, "visible", false)
        }

        function test_seek_bar_on_its_own() {
            const isl = createTemporaryObject(islandFake, stage)
            const bar = createTemporaryObject(seekComp, stage, { island: isl, y: 100 })
            compare(bar.fraction, 0.25)
            const area = findChild(bar, "peekSeekArea")
            mouseClick(area, Math.round(area.width * 0.75), area.height / 2)
            verify(Math.abs(bar.island.player.position - 150000000) < 1000000)
        }

        function test_tour_card_on_its_own() {
            const isl = createTemporaryObject(islandFake, stage)
            isl.mode = "tour"
            const card = createTemporaryObject(tourComp, isl, { island: isl })
            compare(findChild(card, "tourTitle").text, L.TOUR[0].title)
            mouseClick(findChild(card, "tourNext"))
            compare(isl.nextCalls, 1)
            wait(Qt.styleHints.mouseDoubleClickInterval + 50)
            mouseClick(findChild(card, "tourSkip"))
            compare(isl.skipCalls, 1)
        }

        function test_menu_on_its_own() {
            const isl = createTemporaryObject(islandFake, stage)
            isl.mode = "menu"
            isl.width = 290
            isl.height = 16 + 4 * 36
            const menu = createTemporaryObject(menuComp, isl, { island: isl })
            tryVerify(() => findChild(menu, "menu-settings") !== null)
            mouseClick(findChild(menu, "menu-settings"))
            wait(Qt.styleHints.mouseDoubleClickInterval + 50)
            mouseClick(findChild(menu, "menu-timer-25"))
            compare(isl.picked, ["settings", "timers:25"])
        }
    }
}
