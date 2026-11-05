import QtQuick
import QtTest
import "../qml"
import "../qml/logic.js" as L

Item {
    id: stage
    width: 1100
    height: 520

    // Fakes are copied when passed between var properties, so call counts live here.
    property var calls: ({ playPause: 0, next: 0, previous: 0, positionUpdates: 0 })

    function fakePlayer(props) {
        return Object.assign({
            playbackStatus: L.Status.Playing,
            track: "Evaluasi",
            artist: "Hindia",
            artUrl: "",
            identity: "Brave",
            canGoNext: true,
            canGoPrevious: true,
            position: 92000000,
            length: 241000000,
            PlayPause() { stage.calls.playPause++ },
            Next() { stage.calls.next++ },
            Previous() { stage.calls.previous++ },
            updatePosition() { stage.calls.positionUpdates++ }
        }, props)
    }

    Component {
        id: centeredComp
        Item {
            width: 0
            property alias island: isl
            Island { id: isl; anchors.horizontalCenter: parent.horizontalCenter; systemControls: false }
        }
    }

    Component {
        id: timerFake
        QtObject {
            property bool running: true
            property bool paused: false
            property real remainingMs: 272000
            property real pausedRemainingMs: 0
            property int pauseCalls: 0
            property real addedMinutes: 0
            function pause() { pauseCalls++ }
            function addMinutes(m) { addedMinutes += m; remainingMs += m * 60000 }
            property real startedMinutes: 0
            function start(m) { startedMinutes = m }
            function resume() {}
        }
    }

    Component {
        id: islandComp
        Island { x: 100; y: 20; systemControls: false }
    }

    TestCase {
        name: "Island"
        when: windowShown

        function make(props, withTimer) {
            const fake = props === null ? null : stage.fakePlayer(props)
            const timer = withTimer ? createTemporaryObject(timerFake, stage) : null
            const island = createTemporaryObject(islandComp, stage, { player: fake, timer: timer, cycleInterval: 200 })
            return { island, fake, timer }
        }

        function init() {
            stage.calls = { playPause: 0, next: 0, previous: 0, positionUpdates: 0 }
            mouseMove(stage, 1090, 510)
        }

        function jobsOf(n, extra) {
            const shown = []
            for (let i = 0; i < n; ++i)
                shown.push(Object.assign({ startMs: 0, title: "Copying", descriptionValue2: "/home/alnyz/Downloads/file" + i + ".bin", percent: 50 }, extra || {}))
            return { shown: shown, count: n, percent: 57 }
        }

        function test_jobs_is_an_activity() {
            const { island } = make(null)
            island.jobs = jobsOf(1)
            tryCompare(island, "mode", "compact")
            compare(island.activity, "jobs")
            island.player = stage.fakePlayer({})
            compare(island.activities, ["music", "jobs"])
        }

        function test_jobs_compact_shows_summary() {
            const { island } = make(null)
            island.jobs = jobsOf(3)
            tryCompare(island, "width", island.sizes.compact.w)
            compare(findChild(island, "jobsTitle").text, "3 jobs")
            compare(findChild(island, "jobsPercent").text, "57%")
            const line = findChild(island, "jobsLine")
            tryVerify(() => Math.abs(line.width - line.parent.width * 0.57) <= 1)
        }

        function test_jobs_compact_elides() {
            const { island } = make(null)
            island.jobs = jobsOf(1, { descriptionValue2: "/tmp/" + "x".repeat(120) + ".iso" })
            tryCompare(island, "width", island.sizes.compact.w)
            const title = findChild(island, "jobsTitle")
            compare(title.text, "x".repeat(120) + ".iso")
            verify(title.truncated)
        }

        function test_jobs_peek_caps_rows() {
            const { island } = make(null)
            island.jobs = jobsOf(6)
            tryCompare(island, "mode", "compact")
            mouseMove(island, 10, 10)
            tryCompare(island, "height", 22 + 4 * 42)
            compare(island.width, 360)
            compare(findChild(island, "jobsMore").text, "+3 more")
            verify(findChild(island, "jobsList").visible)
        }

        function test_job_chip_on_music_turn() {
            const { island } = make({})
            island.cycleInterval = 100000
            island.jobs = jobsOf(3)
            compare(island.activity, "music")
            const chip = findChild(island, "jobChip")
            tryCompare(chip, "visible", true)
            compare(findChild(island, "jobChipText").text, "3 · 57%")
            island.jobs = jobsOf(1)
            compare(findChild(island, "jobChipText").text, "57%")
            island.jobs = { shown: [], count: 0, percent: 0 }
            tryCompare(chip, "visible", false)
        }

        function test_input_rect_follows_position() {
            const holder = createTemporaryObject(centeredComp, stage)
            const island = holder.island
            tryCompare(island, "width", 180)
            holder.width = 900
            compare(island.inputRect.x, 360)
            compare(island.inputRect.width, 180)
            compare(island.inputRect.height, 32)
        }

        function test_custom_shape() {
            const { island } = make(null)
            island.idleWidth = 200
            island.barHeight = 36
            tryCompare(island, "width", 200)
            tryCompare(island, "height", 36)
            island.player = stage.fakePlayer({})
            island.compactWidth = 300
            tryCompare(island, "width", 300)
        }

        function test_open_on_hover() {
            const { island } = make()
            island.openOnHover = true
            mouseMove(island, 10, 10)
            tryCompare(island, "open", true, 1500)
        }

        function test_settings_button() {
            const { island } = make()
            let asked = 0
            island.settingsRequested.connect(() => asked++)
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "open", true)
            tryCompare(island, "height", island.size.h)
            mouseClick(findChild(island, "settingsButton"))
            compare(asked, 1)
            compare(island.open, false)
        }

        function test_idle_shows_clock_and_weather() {
            const { island } = make(null)
            island.weather = { temperature: 32, code: 3 }
            island.now = () => new Date(2026, 9, 23, 16, 35)
            island.refreshGlance()
            compare(findChild(island, "glanceTime").text, "16:35")
            compare(findChild(island, "glanceWeather").text, "32°")
        }

        function test_idle_shows_pending_updates() {
            const { island } = make(null)
            island.now = () => new Date(2026, 9, 23, 16, 35)
            island.glances = { events: true, battery: true, time: true, weather: true, updates: true }
            island.updates = 12
            island.refreshGlance()
            compare(findChild(island, "glanceUpdates").visible, true)
            compare(findChild(island, "glanceUpdates").text, "12")
            island.updates = 0
            island.refreshGlance()
            compare(findChild(island, "glanceUpdates").visible, false)
        }

        function test_idle_shows_event_soon() {
            const { island } = make(null)
            island.now = () => new Date(2026, 9, 23, 16, 35)
            island.calendar = { upNext: () => [{ title: "Gym", start: new Date(2026, 9, 23, 17, 0), end: new Date(2026, 9, 23, 18, 0), allDay: false }] }
            island.refreshGlance()
            compare(island.glance.kind, "event")
            compare(findChild(island, "glanceTitle").text, "Gym")
            compare(findChild(island, "glanceDetail").text, "in 25 min")
        }

        Component {
            id: undoStoreFake
            QtObject {
                property var items: [{ id: "a", text: "Buy milk", done: false }]
                property var nextOpen: ({})
                property var log: []
                // TodoStore's API
                function add(t) {}
                function setDone(id, d) {}
                function remove(id) { log.push("remove:" + id); return { item: items[0], index: 0 } }
                function restore(r) { log.push("restore:" + r.item.id) }
                function clearDone() {}
                // ClipboardHistory's API
                function take(id) { log.push("take:" + id); return { item: { id: id }, index: 0 } }
                function discard(t) { log.push("discard:" + t.item.id) }
                function copy(id) {}
                function pin(id, on) {}
                function clear() {}
            }
        }

        // Opens the panel on a tab with the pointer resting on it, so it doesn't close by itself.
        function openTab(island, tab) {
            island.open = true
            const panel = findChild(island, "homePanel")
            panel.tab = tab
            tryCompare(island, "height", 420)
            mouseMove(island, island.width - 20, island.height - 20)
            return panel
        }

        function test_undo_deleted_task() {
            const { island } = make(null)
            const store = createTemporaryObject(undoStoreFake, stage)
            island.todos = store
            const panel = openTab(island, "todo")
            tryCompare(island, "height", 420)
            mouseClick(findChild(island, "todoDelete0"))
            compare(store.log, ["remove:a"])
            const bar = findChild(island, "undoBar")
            tryCompare(bar, "opacity", 1)
            compare(findChild(island, "undoText").text, "Task deleted")
            mouseClick(findChild(island, "undoButton"))
            compare(store.log, ["remove:a", "restore:a"])
            tryCompare(bar, "visible", false)
            compare(island.open, true)
        }

        function test_undo_runs_out_and_discards_clipboard_image() {
            const { island } = make(null)
            const store = createTemporaryObject(undoStoreFake, stage)
            store.items = [{ id: "c1", kind: "text", text: "hello", time: Date.now(), pinned: false }]
            island.clipboard = store
            const panel = openTab(island, "clipboard")
            panel.undoMs = 150
            tryCompare(island, "height", 420)
            const del = findChild(island, "clipDelete")
            verify(del)
            mouseClick(del)
            compare(store.log, ["take:c1"])
            compare(findChild(island, "undoText").text, "Clipboard item deleted")
            tryCompare(store, "log", ["take:c1", "discard:c1"], 2000)
            // It ran out while the panel stayed open.
            compare(island.open, true)
            tryCompare(findChild(island, "undoBar"), "visible", false)
        }

        function test_closing_panel_ends_undo() {
            const { island } = make(null)
            const store = createTemporaryObject(undoStoreFake, stage)
            store.items = [{ id: "c1", kind: "text", text: "hello", time: Date.now(), pinned: false }]
            island.clipboard = store
            openTab(island, "clipboard")
            tryCompare(island, "height", 420)
            mouseClick(findChild(island, "clipDelete"))
            island.open = false
            tryCompare(store, "log", ["take:c1", "discard:c1"])
        }

        Component {
            id: todoStoreFake
            QtObject {
                property var items: []
                property var nextOpen: ({})
                function add(t) {}
                function setDone(id, d) {}
                function remove(id) {}
                function clearDone() {}
            }
        }

        Component {
            id: todoFake
            QtObject {
                property var nextOpen: ({ id: "t1", text: "Send invoice", done: false })
            }
        }

        function test_idle_shows_next_task_and_ticks_it() {
            const { island } = make(null)
            const todos = createTemporaryObject(todoFake, stage)
            island.todos = todos
            island.refreshGlance()
            compare(island.glance.kind, "todo")
            compare(findChild(island, "glanceTitle").text, "Send invoice")
            tryCompare(island, "width", 250)
            let ticked = ""
            island.todoDone.connect(id => ticked = id)
            mouseClick(findChild(island, "glanceTodoCheck"))
            compare(ticked, "t1")
            // Ticking never opens the panel.
            compare(island.open, false)
            todos.nextOpen = ({})
            island.refreshGlance()
            compare(island.glance.kind, "clock")
        }

        function test_join_button_opens_link() {
            const { island } = make(null)
            let link = ""
            island.linkRequested.connect(u => link = u)
            island.now = () => new Date(2026, 9, 23, 16, 58)
            island.calendar = { upNext: () => [{ title: "Sync", start: new Date(2026, 9, 23, 17, 0), end: new Date(2026, 9, 23, 18, 0), allDay: false, link: "https://meet.google.com/x" }] }
            island.refreshGlance()
            const join = findChild(island, "glanceJoin")
            tryCompare(join, "visible", true)
            tryCompare(island, "width", 290)
            mouseClick(join)
            compare(link, "https://meet.google.com/x")
            compare(island.open, false)
        }

        function test_builtin_animation() {
            const { island } = make(null)
            island.idleMode = "animation"
            island.idleAnimation = "builtin:cat"
            compare(findChild(island, "idleArt").visible, true)
            compare(findChild(island, "idleArt").name, "cat")
            compare(findChild(island, "idleAnimation").visible, false)
        }

        function test_idle_animation_and_nothing() {
            const { island } = make(null)
            island.idleMode = "animation"
            island.idleAnimation = "file:///nonexistent.gif"
            compare(findChild(island, "idleAnimation").visible, true)
            compare(findChild(island, "glanceRow").visible, false)
            island.idleMode = "nothing"
            compare(findChild(island, "idleAnimation").visible, false)
            compare(findChild(island, "glanceRow").visible, false)
        }

        function test_history_chip_shows_count() {
            const { island } = make(null)
            island.newNotifications = 3
            const chip = findChild(island, "historyChip")
            tryCompare(chip, "visible", true)
            compare(findChild(island, "historyChipText").text, "3")
            island.newNotifications = 0
            compare(chip.visible, false)
        }

        function test_history_chip_hidden_outside_glances() {
            const { island } = make(null)
            island.newNotifications = 3
            island.idleMode = "animation"
            compare(findChild(island, "historyChip").visible, false)
            island.idleMode = "nothing"
            compare(findChild(island, "historyChip").visible, false)
        }

        function test_history_chip_hidden_off_idle() {
            const { island } = make({})
            island.newNotifications = 3
            compare(island.mode, "compact")
            compare(findChild(island, "historyChip").visible, false)
        }

        function test_history_chip_widens_idle() {
            const { island } = make(null)
            island.now = () => new Date(2026, 9, 23, 16, 35)
            island.calendar = { upNext: () => [{ title: "Quarterly planning review with the whole design team", start: new Date(2026, 9, 23, 17, 0), end: new Date(2026, 9, 23, 18, 0), allDay: false }] }
            island.refreshGlance()
            tryCompare(island, "width", 230)
            island.newNotifications = 3
            tryVerify(() => island.width > 230)
            const chip = findChild(island, "historyChip")
            const row = findChild(island, "glanceRow")
            const chipX = chip.mapToItem(island, 0, 0).x
            const rowEnd = row.mapToItem(island, row.width, 0).x
            verify(chipX >= rowEnd, chipX + " >= " + rowEnd)
        }

        function test_history_chip_beside_battery_ring() {
            const { island } = make(null)
            island.battery = 60
            island.now = () => new Date(2026, 9, 23, 16, 35)
            island.refreshGlance()
            island.newNotifications = 3
            const ring = findChild(island, "batteryRing")
            const chip = findChild(island, "historyChip")
            tryCompare(chip, "visible", true)
            verify(ring.visible)
            verify(chip.mapToItem(island, chip.width, 0).x <= ring.mapToItem(island, 0, 0).x)
        }

        function test_timer_only_is_compact() {
            const { island } = make(null, true)
            compare(island.mode, "compact")
            compare(island.activity, "timer")
            compare(findChild(island, "timerText").text, "4:32")
            compare(findChild(island, "dots").visible, false)
        }

        function test_cycles_between_activities() {
            const { island } = make({}, true)
            compare(island.activities, ["music", "timer"])
            compare(island.activity, "music")
            compare(findChild(island, "dots").visible, true)
            tryCompare(island, "activity", "timer", 1000)
            tryCompare(island, "activity", "music", 1000)
        }

        function test_swipe_switches_and_pauses_cycle() {
            const { island } = make({}, true)
            island.cycleInterval = 60000
            mouseWheel(island, 10, 10, -120, 0)
            compare(island.activity, "timer")
            compare(island.cyclePaused, true)
            wait(400)
            mouseWheel(island, 10, 10, 120, 0)
            compare(island.activity, "music")
        }

        function test_one_swipe_is_one_step() {
            const { island } = make({}, true)
            island.cycleInterval = 60000
            // A touchpad swipe arrives as a burst of wheel events, including momentum after lift-off.
            for (let i = 0; i < 8; ++i)
                mouseWheel(island, 10, 10, -60, 0)
            compare(island.activity, "timer")
            wait(400)
            mouseWheel(island, 10, 10, -120, 0)
            compare(island.activity, "music")
        }

        SignalSpy { id: volumeSpy; signalName: "volumeStep" }

        function test_scroll_up_down_changes_volume() {
            const { island } = make({})
            volumeSpy.target = island
            volumeSpy.clear()
            mouseWheel(island, 10, 10, 0, 120)
            compare(volumeSpy.count, 1)
            compare(volumeSpy.signalArguments[0][0], 1)
            mouseWheel(island, 10, 10, 0, -240)
            compare(volumeSpy.signalArguments[1][0], -2)
            // Small touchpad deltas add up to one step.
            mouseWheel(island, 10, 10, 0, 60)
            compare(volumeSpy.count, 2)
            mouseWheel(island, 10, 10, 0, 60)
            compare(volumeSpy.count, 3)
            // Scrolling never switches the turn.
            compare(island.activity, "music")
        }

        function test_scroll_idle_changes_volume() {
            const { island } = make(null)
            volumeSpy.target = island
            volumeSpy.clear()
            mouseWheel(island, 10, 10, 0, 120)
            compare(volumeSpy.count, 1)
        }

        function test_scroll_over_timer_changes_minutes() {
            const { island, timer } = make(null, true)
            volumeSpy.target = island
            volumeSpy.clear()
            compare(island.activity, "timer")
            mouseWheel(island, 10, 10, 0, 120)
            compare(timer.addedMinutes, 1)
            mouseWheel(island, 10, 10, 0, -360)
            compare(timer.addedMinutes, -2)
            compare(volumeSpy.count, 0)
        }

        function test_scroll_ignored_while_open() {
            const { island } = make({})
            volumeSpy.target = island
            volumeSpy.clear()
            island.open = true
            mouseWheel(island, 10, 10, 0, 120)
            compare(volumeSpy.count, 0)
        }

        function test_middle_click_plays_and_pauses() {
            const { island } = make({})
            mouseClick(island, 10, 10, Qt.MiddleButton)
            compare(stage.calls.playPause, 1)
            wait(400)
            compare(island.open, false)
        }

        function test_double_click_skips() {
            const { island } = make({})
            mouseDoubleClickSequence(island, 10, 10)
            compare(stage.calls.next, 1)
            wait(400)
            compare(island.open, false)
        }

        function test_single_click_on_music_still_opens() {
            const { island } = make({})
            mouseClick(island, 10, 10)
            compare(island.open, false)
            tryCompare(island, "open", true, 1000)
            compare(stage.calls.next, 0)
        }

        function test_click_without_music_opens_at_once() {
            const { island } = make(null)
            mouseClick(island, 10, 10)
            compare(island.open, true)
        }

        function test_peek_seek_bar_jumps() {
            const { island } = make({ position: 0, length: 200000000 })
            mouseMove(island, 10, 10)
            tryCompare(island, "mode", "peek")
            tryCompare(island, "height", 60)
            const seek = findChild(island, "peekSeekArea")
            verify(findChild(island, "peekSeek").visible)
            mouseClick(seek, seek.width / 2, seek.height / 2)
            compare(island.player.position, 100000000)
            // Seeking never opens the panel.
            wait(400)
            compare(island.open, false)
        }

        function test_peek_seek_bar_drags() {
            const { island } = make({ position: 0, length: 200000000 })
            mouseMove(island, 10, 10)
            tryCompare(island, "height", 60)
            const seek = findChild(island, "peekSeekArea")
            const bar = findChild(island, "peekSeek")
            const x = Math.round(seek.width / 4)
            mousePress(seek, 2, seek.height / 2)
            mouseMove(seek, x, seek.height / 2)
            // The bar follows the pointer before the player is told.
            compare(bar.fraction, x / seek.width)
            compare(island.player.position, 0)
            mouseRelease(seek, x, seek.height / 2)
            compare(island.player.position, Math.round(x / seek.width * 200000000))
            compare(bar.dragFraction, -1)
        }

        function test_peek_seek_bar_hidden_without_length() {
            const { island } = make({ length: 0 })
            mouseMove(island, 10, 10)
            tryCompare(island, "mode", "peek")
            compare(findChild(island, "peekSeek").visible, false)
        }

        SignalSpy { id: menuSpy; signalName: "menuAction" }

        function test_right_click_opens_menu() {
            const { island } = make({})
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10, Qt.RightButton)
            compare(island.mode, "menu")
            tryCompare(island, "height", 16 + 4 * 36)
            verify(findChild(island, "menu-dnd-hour").visible)
            verify(findChild(island, "menu-hide-hour").visible)
            verify(findChild(island, "menu-settings").visible)
            // The panel never opens from a right click.
            wait(400)
            compare(island.open, false)
        }

        function test_menu_rows_send_actions() {
            const { island } = make(null)
            menuSpy.target = island
            menuSpy.clear()
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10, Qt.RightButton)
            tryCompare(island, "height", island.size.h)
            mouseClick(findChild(island, "menu-dnd-hour"))
            compare(menuSpy.count, 1)
            compare(menuSpy.signalArguments[0][0], "dnd-hour")
            compare(island.menuOpen, false)

            island.dnd = true
            mouseClick(island, 10, 10, Qt.RightButton)
            tryCompare(island, "height", island.size.h)
            verify(findChild(island, "menu-dnd-off").visible)
            mouseClick(findChild(island, "menu-settings"))
            compare(menuSpy.signalArguments[1][0], "settings")
        }

        function test_menu_starts_timer() {
            const { island, timer } = make(null, true)
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10, Qt.RightButton)
            tryCompare(island, "height", island.size.h)
            mouseClick(findChild(island, "menu-timer-10"))
            compare(timer.startedMinutes, 10)
            compare(island.menuOpen, false)
        }

        function test_menu_closes_when_pointer_leaves() {
            const { island } = make(null)
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10, Qt.RightButton)
            compare(island.mode, "menu")
            mouseMove(stage, 1090, 510)
            tryCompare(island, "menuOpen", false, 2000)
            tryCompare(island, "mode", "idle")
        }

        function test_left_click_closes_menu_without_opening() {
            const { island } = make(null)
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10, Qt.RightButton)
            tryCompare(island, "height", island.size.h)
            // Below the rows, in the menu's padding.
            mouseClick(island, island.width / 2, island.height - 3)
            compare(island.menuOpen, false)
            compare(island.open, false)
        }

        function test_hidden_by_user_folds_away() {
            const { island } = make(null)
            island.hiddenByUser = true
            compare(island.tucked, true)
            tryCompare(island, "height", 0)
            // Alerts still come out of the sliver.
            island.showAlert({ kind: "volume", value: 40, muted: false }, 2000)
            compare(island.tucked, false)
            tryCompare(island, "height", 32)
        }

        function test_tour_steps_through_and_finishes() {
            const { island } = make({})
            let finished = 0
            island.tourFinished.connect(() => finished++)
            island.startTour()
            compare(island.mode, "tour")
            tryCompare(island, "height", 116)
            compare(findChild(island, "tourTitle").text, L.TOUR[0].title)
            mouseClick(findChild(island, "tourNext"))
            compare(island.tourStep, 1)
            compare(findChild(island, "tourTitle").text, L.TOUR[1].title)
            mouseClick(findChild(island, "tourNext"))
            compare(findChild(island, "tourSkip").visible, false)
            mouseClick(findChild(island, "tourNext"))
            compare(island.tourActive, false)
            compare(finished, 1)
            tryCompare(island, "mode", "compact")
        }

        function test_tour_text_fits() {
            const { island } = make(null)
            island.startTour()
            tryCompare(island, "height", 116)
            for (let i = 0; i < L.TOUR.length; ++i) {
                island.tourStep = i
                wait(0)
                compare(findChild(island, "tourBody").truncated, false, "step " + i)
            }
        }

        function test_tour_skip_and_no_accidental_open() {
            const { island } = make(null)
            let finished = 0
            island.tourFinished.connect(() => finished++)
            island.startTour()
            tryCompare(island, "height", 116)
            // A click on the card's text area does nothing.
            mouseClick(island, 100, 30)
            wait(300)
            compare(island.open, false)
            compare(island.mode, "tour")
            mouseClick(findChild(island, "tourSkip"))
            compare(finished, 1)
            compare(island.mode, "idle")
        }

        function test_tour_closes_open_panel() {
            const { island } = make(null)
            island.open = true
            island.startTour()
            compare(island.open, false)
            compare(island.mode, "tour")
        }

        function test_keyboard_switches_tabs() {
            const { island } = make({})
            island.toggleFromKeyboard()
            tryCompare(island, "mode", "open")
            const panel = findChild(island, "homePanel")
            panel.forceActiveFocus()
            compare(panel.tab, "home")
            keyClick(Qt.Key_2)
            compare(panel.tab, "music")
            keyClick(Qt.Key_Tab)
            compare(panel.tab, "timer")
            keyClick(Qt.Key_Backtab, Qt.ShiftModifier)
            compare(panel.tab, "music")
            // Past the last tab number nothing happens.
            keyClick(Qt.Key_9)
            compare(panel.tab, "music")
            keyClick(Qt.Key_1)
            keyClick(Qt.Key_Backtab, Qt.ShiftModifier)
            compare(panel.tab, panel.tabKeys[panel.tabKeys.length - 1])
        }

        function test_keyboard_plays_and_seeks() {
            const { island } = make({ position: 60000000, length: 200000000 })
            island.toggleFromKeyboard()
            tryCompare(island, "mode", "open")
            const panel = findChild(island, "homePanel")
            panel.forceActiveFocus()
            keyClick(Qt.Key_Space)
            compare(stage.calls.playPause, 1)
            // Fakes are copied into the panel, so read its copy.
            keyClick(Qt.Key_Right)
            compare(panel.player.position, 65000000)
            keyClick(Qt.Key_Left)
            keyClick(Qt.Key_Left)
            compare(panel.player.position, 55000000)
        }

        function test_typing_in_a_tab_keeps_its_keys() {
            const { island } = make({})
            island.todos = createTemporaryObject(todoStoreFake, stage)
            island.toggleFromKeyboard()
            tryCompare(island, "mode", "open")
            const panel = findChild(island, "homePanel")
            panel.tab = "todo"
            const input = findChild(island, "todoInput")
            verify(input)
            input.forceActiveFocus()
            keyClick(Qt.Key_2)
            keyClick(Qt.Key_Space)
            compare(panel.tab, "todo")
            compare(input.text, "2 ")
            compare(stage.calls.playPause, 0)
        }

        function test_cover_colour_tints_music() {
            const { island } = make({ position: 50000000, length: 200000000 })
            compare(findChild(island, "bars").color, Qt.color("#e8e2d0"))
            compare(island.musicTint, island.palette.accent)
            island.coverTinted = true
            island.coverTint = "#e0403a"
            tryCompare(findChild(island, "bars"), "color", Qt.color("#e0403a"))
            compare(island.musicTint, Qt.color("#e0403a"))
            mouseMove(island, 10, 10)
            tryCompare(island, "mode", "peek")
            compare(findChild(island, "peekSeekFill").color, Qt.color("#e0403a"))
            island.open = true
            tryCompare(island, "height", island.size.h)
            compare(findChild(island, "cardProgressFill").color, Qt.color("#e0403a"))
            // No usable colour: back to the usual look.
            island.coverTinted = false
            compare(findChild(island, "cardProgressFill").color, Qt.color("#e8e2d0"))
        }

        function test_cover_flies_into_the_panel() {
            const { island } = make({})
            mouseMove(island, 10, 10)
            tryCompare(island, "mode", "peek")
            island.open = true
            const flyer = findChild(stage, "coverFlyer")
            verify(flyer)
            compare(flyer.visible, true)
            const panel = findChild(island, "homePanel")
            compare(panel.coverHidden, true)
            compare(findChild(island, "cardCover").opacity, 0)
            // It lands on the card's cover and hands over to it.
            tryCompare(flyer, "visible", false, 2000)
            compare(panel.coverHidden, false)
            compare(findChild(island, "cardCover").opacity, 1)
            const card = findChild(island, "cardCover").mapToItem(stage, 0, 0)
            compare(Math.round(flyer.x), Math.round(card.x))
            compare(Math.round(flyer.y), Math.round(card.y))
            compare(Math.round(flyer.width), 56)
        }

        function test_closing_mid_flight_drops_the_flyer() {
            const { island } = make({})
            mouseMove(island, 10, 10)
            tryCompare(island, "mode", "peek")
            island.open = true
            const flyer = findChild(stage, "coverFlyer")
            compare(flyer.visible, true)
            island.open = false
            compare(flyer.visible, false)
        }

        function test_no_flight_without_music() {
            const { island } = make(null)
            island.open = true
            const flyer = findChild(stage, "coverFlyer")
            compare(flyer.visible, false)
            compare(findChild(island, "homePanel").coverHidden, false)
        }

        function test_no_flight_to_a_tab_without_cover() {
            const { island } = make({})
            mouseMove(island, 10, 10)
            tryCompare(island, "mode", "peek")
            island.requestedTab = "timer"
            island.open = true
            compare(findChild(stage, "coverFlyer").visible, false)
        }

        function test_peek_shows_current_activity() {
            const { island, timer } = make(null, true)
            mouseMove(island, 10, 10)
            tryCompare(island, "mode", "peek")
            compare(findChild(island, "peekTimerText").visible, true)
            mouseClick(findChild(island, "peekTimerToggle"))
            compare(timer.pauseCalls, 1)
        }

        function test_pill_is_a_capsule_when_closed() {
            const { island } = make(null)
            island.pill = true
            tryCompare(findChild(island, "islandShape"), "r", 16)
            island.open = true
            tryCompare(findChild(island, "islandShape"), "r", 30)
        }

        function test_idle_without_player() {
            const { island } = make(null)
            compare(island.mode, "idle")
            tryCompare(island, "width", 180)
            tryCompare(island, "height", 32)
        }

        function test_compact_with_player() {
            const { island } = make()
            compare(island.mode, "compact")
            tryCompare(island, "width", 260)
            tryCompare(island, "height", 32)
            compare(findChild(island, "bars").running, true)
            const paused = make({ playbackStatus: L.Status.Paused }).island
            // A paused player no longer takes a turn; the pill goes back to idle.
            compare(paused.mode, "idle")
        }

        function test_hover_peek() {
            const { island } = make()
            mouseMove(island, 10, 10)
            tryCompare(island, "mode", "peek")
            compare(findChild(island, "title").text, "Evaluasi")
        }

        function test_click_open_and_controls() {
            const { island } = make()
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "mode", "open")
            tryCompare(island, "height", island.size.h)
            mouseClick(findChild(island, "tab-music"))
            mouseClick(findChild(island, "playPause"))
            compare(stage.calls.playPause, 1)
            mouseClick(findChild(island, "next"))
            compare(stage.calls.next, 1)
        }

        function test_disabled_prev_ignores_click() {
            const { island } = make({ canGoPrevious: false })
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "open", true)
            tryCompare(island, "height", island.size.h)
            mouseClick(findChild(island, "tab-music"))
            const prev = findChild(island, "prev")
            mouseClick(prev)
            compare(stage.calls.previous, 0)
            fuzzyCompare(prev.opacity, 0.35, 0.01)
        }

        function test_open_without_player() {
            const { island } = make(null)
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "mode", "open")
            tryCompare(island, "width", 860)
        }

        function test_open_survives_player_leaving() {
            const { island } = make()
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "mode", "open")
            island.player = null
            compare(island.mode, "open")
        }

        function test_home_tab_fits_its_content() {
            for (const props of [null, {}]) {
                const { island } = make(props)
                mouseMove(island, 10, 10)
                mouseClick(island, 10, 10)
                tryCompare(island, "mode", "open")
                tryCompare(island, "height", island.size.h)
                const content = findChild(island, "tabContent")
                compare(findChild(island, "homeTab").implicitHeight, content.height)
                if (props === null)
                    verify(island.height < 420)
                mouseClick(findChild(island, "tab-music"))
                tryCompare(island, "height", 420)
                island.open = false
            }
        }

        function test_panel_shows_clock() {
            const { island } = make()
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "open", true)
            tryCompare(island, "height", island.size.h)
            const panel = findChild(island, "homePanel")
            panel.now = () => new Date(2026, 9, 23, 9, 5)
            panel.refreshClock()
            compare(findChild(island, "panelTime").text, "09:05")
            compare(findChild(island, "panelDate").text, Qt.formatDate(new Date(2026, 9, 23), "ddd d MMM"))

            island.panelTime = false
            compare(findChild(island, "panelTime").visible, false)
            compare(findChild(island, "panelDate").visible, true)
            island.panelDate = false
            compare(findChild(island, "panelDate").visible, false)
        }

        function test_only_open_tab_shows_name() {
            const { island } = make()
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "open", true)
            tryCompare(island, "height", island.size.h)
            tryCompare(findChild(island, "tabLabel-home"), "opacity", 1)
            compare(findChild(island, "tabLabel-music").opacity, 0)
            mouseClick(findChild(island, "tab-music"))
            tryCompare(findChild(island, "tabLabel-music"), "opacity", 1)
            tryCompare(findChild(island, "tabLabel-home"), "opacity", 0)
        }

        function test_quick_link_opens() {
            const { island } = make()
            island.links = [{ name: "Reports", url: "https://example.com" }]
            let opened = ""
            island.linkRequested.connect(url => opened = url)
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "open", true)
            tryCompare(island, "height", island.size.h)
            mouseClick(findChild(island, "tab-more"))
            mouseClick(findChild(island, "menu-links"))
            mouseClick(findChild(island, "link-0"))
            compare(opened, "https://example.com")
            compare(island.open, false)
        }

        function test_color_tab_picks_and_copies() {
            const { island } = make()
            island.colors = ["#ff375f"]
            let picks = 0, copied = ""
            island.colorPickRequested.connect(() => picks++)
            island.copyRequested.connect(t => copied = t)
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "open", true)
            tryCompare(island, "height", island.size.h)
            mouseClick(findChild(island, "tab-more"))
            mouseClick(findChild(island, "menu-color"))
            mouseClick(findChild(island, "format-rgb"))
            compare(copied, "rgb(255, 55, 95)")
            mouseClick(findChild(island, "pickColor"))
            compare(picks, 1)
            compare(island.open, false)
        }

        function test_more_menu_picks_extra_tab() {
            const { island } = make()
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "open", true)
            tryCompare(island, "height", island.size.h)
            compare(findChild(island, "tabLabel-extra").text, "Clipboard")
            mouseClick(findChild(island, "tab-more"))
            const menu = findChild(island, "moreMenu")
            compare(menu.visible, true)
            mouseClick(findChild(island, "menu-notes"))
            compare(menu.visible, false)
            compare(findChild(island, "homePanel").tab, "notes")
            compare(island.extraTool, "notes")
            compare(findChild(island, "tabLabel-extra").text, "Notes")
            compare(island.wantsKeyboard, true)
            mouseClick(findChild(island, "tab-home"))
            compare(island.wantsKeyboard, false)
        }

        function test_volume_alert_then_back() {
            const { island } = make(null)
            island.showAlert({ kind: "volume", value: 64, muted: false }, 1000)
            compare(island.mode, "alert")
            tryCompare(island, "width", 300)
            compare(findChild(island, "alertLevelText").text, "64")
            tryCompare(island, "mode", "idle")
        }

        function test_keyboard_open_ignores_far_pointer() {
            const { island } = make(null)
            island.toggleFromKeyboard()
            tryCompare(island, "mode", "open")
            wait(1000)
            compare(island.open, true)
            mouseMove(island, 20, 20)
            mouseMove(stage, 1090, 510)
            tryCompare(island, "open", false, 1500)
        }

        function test_keyboard_toggle_and_escape() {
            const { island } = make(null)
            island.toggleFromKeyboard()
            tryCompare(island, "mode", "open")
            island.toggleFromKeyboard()
            compare(island.open, false)
            island.toggleFromKeyboard()
            tryCompare(island, "mode", "open")
            findChild(island, "homePanel").forceActiveFocus()
            keyClick(Qt.Key_Escape)
            compare(island.open, false)
            compare(island.openedByKeyboard, false)
        }

        function test_hides_behind_full_screen() {
            const { island } = make(null)
            island.coveredByFullScreen = true
            tryCompare(island, "height", 0)
            verify(!island.wantsFront)
            island.showAlert({ kind: "notification", title: "Rina", body: "hi", icon: "", desktopEntry: "" }, 400)
            verify(island.wantsFront)
            tryCompare(island, "height", 64)
            tryCompare(island, "height", 0, 2000)
            tryCompare(island, "wantsFront", false)
        }

        function test_tucked_pill_shows_nothing() {
            const { island } = make(null)
            island.coveredByFullScreen = true
            verify(island.clip)
            island.showAlert({ kind: "volume", value: 40, muted: false }, 1000)
            verify(!island.clip)
        }

        function test_repeated_levels_stay_in_front() {
            const { island } = make(null)
            island.coveredByFullScreen = true
            tryCompare(island, "height", 0)
            // Long enough to finish growing; the repeats below each keep it up for 300 ms.
            island.showAlert({ kind: "volume", value: 40, muted: false }, 1500)
            tryCompare(island, "height", 32)
            for (let i = 0; i < 4; ++i) {
                wait(150)
                island.showAlert({ kind: "volume", value: 45 + i * 5, muted: false }, 300)
                verify(island.wantsFront)
                verify(island.height > 20)
            }
        }

        function test_full_screen_ends_during_alert() {
            const { island } = make(null)
            island.coveredByFullScreen = true
            island.showAlert({ kind: "volume", value: 40, muted: false }, 2000)
            tryCompare(island, "height", 32)
            island.coveredByFullScreen = false
            verify(!island.wantsFront)
            island.alert = null
            tryCompare(island, "height", island.barHeight)
        }

        function test_never_in_front_without_full_screen() {
            const { island } = make(null)
            island.showAlert({ kind: "volume", value: 40, muted: false }, 300)
            verify(!island.wantsFront)
        }

        function test_capslock_alert() {
            const { island } = make(null)
            island.showAlert({ kind: "capslock", on: true }, 3000)
            compare(findChild(island, "capsLockAlertText").text, "Caps Lock on")
            island.showAlert({ kind: "capslock", on: false }, 3000)
            compare(findChild(island, "capsLockAlertText").text, "Caps Lock off")
        }

        function test_privacy_alert() {
            const { island } = make(null)
            island.showAlert({ kind: "privacy", app: "Zoom", device: "microphone" }, 3000)
            tryCompare(island, "width", 330)
            compare(findChild(island, "privacyAlertApp").text, "Zoom")
            compare(findChild(island, "privacyAlertText").text, "is using the microphone")
            island.showAlert({ kind: "privacy", app: "Firefox", device: "camera" }, 3000)
            compare(findChild(island, "privacyAlertText").text, "is using the camera")
        }

        function test_notification_click_opens_app() {
            const { island } = make(null)
            let opened = ""
            island.notificationClicked.connect(e => opened = e)
            island.showAlert({ kind: "notification", title: "Rizky", body: "hi", icon: "discord", desktopEntry: "discord" }, 5000)
            tryCompare(island, "height", 64)
            compare(findChild(island, "alertTitle").text, "Rizky")
            mouseClick(island, 40, 30)
            compare(opened, "discord")
            compare(island.mode, "idle")
            compare(island.open, false)
        }

        function test_notification_buttons_run_actions() {
            const { island } = make(null)
            const ran = []
            let opened = ""
            island.notificationAction.connect((id, key) => ran.push(id + ":" + key))
            island.notificationClicked.connect(e => opened = e)
            island.showAlert({ kind: "notification", title: "Rina", body: "hi", icon: "", desktopEntry: "org.telegram.desktop",
                               serverId: 32, hasDefault: true, buttons: [{ key: "mark", label: "Mark as read" }, { key: "mute", label: "Mute" }] }, 5000)
            tryCompare(island, "height", 100)
            compare(findChild(island, "notificationButtons").visible, true)
            mouseClick(findChild(island, "notificationButton1"))
            compare(ran, ["32:mute"])
            compare(opened, "")
            compare(island.mode, "idle")
        }

        function test_notification_click_uses_default_action() {
            const { island } = make(null)
            const ran = []
            let opened = ""
            island.notificationAction.connect((id, key) => ran.push(id + ":" + key))
            island.notificationClicked.connect(e => opened = e)
            island.showAlert({ kind: "notification", title: "Rina", body: "hi", icon: "", desktopEntry: "org.telegram.desktop",
                               serverId: 7, hasDefault: true, buttons: [] }, 5000)
            tryCompare(island, "height", 64)
            compare(findChild(island, "notificationButtons").visible, false)
            mouseClick(island, 40, 30)
            compare(ran, ["7:default"])
            compare(opened, "")
        }

        function test_notification_waits_while_hovered() {
            const { island } = make(null)
            island.showAlert({ kind: "notification", title: "t", body: "", icon: "", desktopEntry: "" }, 200)
            mouseMove(island, 20, 20)
            wait(400)
            compare(island.mode, "alert")
            mouseMove(stage, 1090, 510)
            tryCompare(island, "mode", "idle")
        }

        function test_job_alert_failed() {
            const { island } = make(null)
            island.showAlert({ kind: "job", ok: false, title: "Copy failed", body: "Photos 2026 · Not enough free space", folder: "" }, 4000)
            tryCompare(island, "height", 64)
            compare(island.width, 400)
            verify(findChild(island, "jobAlert").visible)
            const title = findChild(island, "jobAlertTitle")
            compare(title.text, "Copy failed")
            compare(title.color, Qt.color("#ff8a8a"))
            compare(findChild(island, "jobAlertBody").text, "Photos 2026 · Not enough free space")
        }

        function test_job_alert_click_opens_folder() {
            const { island } = make(null)
            let opened = ""
            island.linkRequested.connect(u => opened = u)
            island.showAlert({ kind: "job", ok: true, title: "Downloaded", body: "a.iso", folder: "file:///home/alnyz/Downloads" }, 4000)
            tryCompare(island, "height", 64)
            compare(findChild(island, "jobAlertTitle").color, Qt.color("#ffffff"))
            mouseClick(island, 40, 30)
            compare(opened, "file:///home/alnyz/Downloads")
            compare(island.mode, "idle")
            compare(island.open, false)
        }

        function test_device_alert() {
            const { island } = make(null)
            island.showAlert({ kind: "device", name: "Galaxy Buds2", icon: "audio-headset", connected: true, battery: 82 }, 5000)
            tryCompare(island, "height", 72)
            compare(findChild(island, "deviceName").text, "Galaxy Buds2")
            compare(findChild(island, "deviceBattery").text, "82%")
            compare(findChild(island, "deviceBattery").visible, true)
        }

        function test_privacy_dots_widen_pill() {
            const { island } = make(null)
            tryCompare(island, "width", 180)
            island.micApps = ["Discord"]
            compare(findChild(island, "micDot").visible, true)
            compare(findChild(island, "cameraDot").visible, false)
            tryVerify(() => island.width > 180)
        }

        function fakeHistory(save) {
            return { settings: { save: save }, groups: [], lastSeen: 0, markSeen() {}, remove() {}, clear() {} }
        }

        function test_notifications_tab_badge() {
            const { island } = make(null)
            island.history = fakeHistory(true)
            island.newNotifications = 4
            island.open = true
            const badge = findChild(island, "notificationsBadge")
            tryVerify(() => badge !== null && badge.visible)
            compare(findChild(badge, "notificationsBadgeText").text, "4")
        }

        function test_notifications_tab_hidden_when_not_saving() {
            const { island } = make(null)
            island.history = fakeHistory(false)
            island.open = true
            tryCompare(island, "mode", "open")
            verify(findChild(island, "tab-home") !== null)
            compare(findChild(island, "tab-notifications"), null)
        }

        function test_close_on_notifications_tab_marks_seen() {
            const { island } = make(null)
            let left = 0
            island.notificationsLeft.connect(() => left++)
            island.history = fakeHistory(true)
            island.requestedTab = "notifications"
            island.open = true
            tryCompare(findChild(island, "homePanel"), "tab", "notifications")
            island.open = false
            tryVerify(() => left === 1)
            wait(100)
            compare(left, 1)
        }

        function test_leaving_notifications_tab_marks_seen() {
            const { island } = make(null)
            let left = 0
            island.notificationsLeft.connect(() => left++)
            island.history = fakeHistory(true)
            island.requestedTab = "notifications"
            island.open = true
            tryCompare(findChild(island, "homePanel"), "tab", "notifications")
            mouseClick(findChild(island, "tab-music"))
            compare(left, 1)
        }

        function test_notification_row_click_closes_panel() {
            const { island } = make(null)
            let opened = ""
            island.notificationClicked.connect(e => opened = e)
            island.history = fakeHistory(true)
            island.requestedTab = "notifications"
            island.open = true
            const tab = findChild(island, "notificationsTab")
            tryVerify(() => tab.item !== null)
            tab.item.openRequested("r1", "org.telegram.desktop")
            compare(opened, "org.telegram.desktop")
            compare(island.open, false)
        }

        function test_shelf_drop_opens_shelf() {
            const { island } = make(null)
            island.addToShelf(["file:///tmp/a.pdf", "file:///tmp/b.png"])
            compare(island.shelf.length, 2)
            compare(island.open, true)
            tryCompare(findChild(island, "homePanel"), "tab", "shelf")
            compare(findChild(island, "shelfCount").text, "2")
        }

        function test_open_starts_on_home() {
            const { island } = make()
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "open", true)
            tryCompare(island, "height", island.size.h)
            mouseClick(findChild(island, "tab-music"))
            compare(findChild(island, "homePanel").tab, "music")
            mouseMove(stage, 1090, 510)
            wait(700)
            compare(island.open, false)
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "mode", "open")
            compare(findChild(island, "homePanel").tab, "home")
        }

        function test_long_title_elides() {
            const { island } = make({ track: "x".repeat(200) })
            mouseMove(island, 10, 10)
            tryCompare(island, "width", 330)
            compare(findChild(island, "title").truncated, true)
        }

        function test_leave_closes_after_delay() {
            const { island } = make()
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "mode", "open")
            mouseMove(stage, 1090, 510)
            wait(700)
            compare(island.open, false)
        }

        function test_open_paused_refreshes_position() {
            const { island } = make({ playbackStatus: L.Status.Paused })
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "mode", "open")
            compare(stage.calls.positionUpdates, 1)
        }
    }
}
