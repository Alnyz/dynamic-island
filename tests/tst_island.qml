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
            function pause() { pauseCalls++ }
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
            tryCompare(island, "height", 420)
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

        function test_idle_shows_event_soon() {
            const { island } = make(null)
            island.now = () => new Date(2026, 9, 23, 16, 35)
            island.calendar = { upNext: () => [{ title: "Gym", start: new Date(2026, 9, 23, 17, 0), end: new Date(2026, 9, 23, 18, 0), allDay: false }] }
            island.refreshGlance()
            compare(island.glance.kind, "event")
            compare(findChild(island, "glanceTitle").text, "Gym")
            compare(findChild(island, "glanceDetail").text, "in 25 min")
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
            compare(paused.mode, "compact")
            compare(findChild(paused, "bars").running, false)
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
            tryCompare(island, "height", 420)
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
            tryCompare(island, "height", 420)
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

        function test_panel_shows_clock() {
            const { island } = make()
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "height", 420)
            const panel = findChild(island, "homePanel")
            panel.now = () => new Date(2026, 9, 23, 9, 5)
            panel.refreshClock()
            compare(findChild(island, "panelTime").text, "09:05")
            compare(findChild(island, "panelDate").text, Qt.formatDate(new Date(2026, 9, 23), "ddd d MMM"))
        }

        function test_only_open_tab_shows_name() {
            const { island } = make()
            mouseMove(island, 10, 10)
            mouseClick(island, 10, 10)
            tryCompare(island, "height", 420)
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
            tryCompare(island, "height", 420)
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
            tryCompare(island, "height", 420)
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
            tryCompare(island, "height", 420)
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

        function test_notification_waits_while_hovered() {
            const { island } = make(null)
            island.showAlert({ kind: "notification", title: "t", body: "", icon: "", desktopEntry: "" }, 200)
            mouseMove(island, 20, 20)
            wait(400)
            compare(island.mode, "alert")
            mouseMove(stage, 1090, 510)
            tryCompare(island, "mode", "idle")
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
            tryCompare(island, "height", 420)
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
