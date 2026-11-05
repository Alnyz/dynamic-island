import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "logic.js" as L
import "weather.js" as W

Item {
    id: island

    property var player: null
    // The player's cover as PlayerSource holds it; player.artUrl itself can blink out.
    property string artUrl: ""
    // The cover's colour (CoverColor), when there is one; music controls use musicTint.
    // The speakers' level (0..1) for the bars, or -1; wantsLevel says when it's needed.
    property real audioLevel: -1
    readonly property bool wantsLevel: playing && mode === "compact" && activity === "music"
    property bool coverTinted: false
    property color coverTint: "transparent"
    readonly property color musicTint: coverTinted ? coverTint : palette.accent
    Behavior on coverTint { ColorAnimation { duration: 400 } }
    property var timer: null
    property var weather: null
    property var calendar: null
    property var sound: null
    property var clipboard: null
    property var notes: null
    property var todos: null
    property var lyrics: null
    // Ticks a task off from the idle pill.
    signal todoDone(string id)
    // NotificationHistory for the Notifications tab, and its new count for the tab's badge.
    property var history: null
    property int newNotifications: 0
    // The amber chip only joins the glances: an animation or an empty pill stays as it is.
    readonly property bool showHistoryChip: mode === "idle" && idleMode === "glances" && newNotifications > 0
    readonly property real historyChipWidth: showHistoryChip ? historyChip.width + 8 : 0
    signal notificationsLeft()
    property string extraTool: "clipboard"
    // The clipboard and notes tabs need typing; the rest of the time the island never takes the keyboard.
    readonly property bool wantsKeyboard: open && panelLoader.item !== null && (panelLoader.item.wantsKeyboard || openedByKeyboard)
    property bool systemControls: true
    property bool open: false
    readonly property bool hovered: hover.hovered
    // Not named `state`: Item already has a `state` property.
    readonly property bool timerActive: timer !== null && (timer.running || timer.paused)
    readonly property var activities: L.activities(island.playing, timerActive, jobs.count > 0)
    property int current: 0
    readonly property string activity: activities.length > 0 ? activities[current % activities.length] : ""
    property int cycleInterval: 6000
    property int swipeHold: 15000
    property int idleWidth: 180
    property int compactWidth: 260
    property int barHeight: 32
    property int cornerRadius: 12
    property int earSize: 8
    // Floating capsule instead of a notch joined to the top edge.
    property bool pill: false
    // Follows the notch/pill morph, so the gap from the screen edge opens with it.
    readonly property real pillAmount: notch.p
    property bool openOnHover: false
    property var quickHidden: []
    // Running jobs as JobsModel.summary gives them: { shown, count, percent }.
    property var jobs: ({ shown: [], count: 0, percent: 0 })
    // At most 4 rows when pointed at; past that, 3 rows and a "+N more" row.
    readonly property int jobRows: Math.min(jobs.count, 4)
    property bool panelTime: true
    property bool panelDate: true
    property var now: () => new Date()
    property int battery: -1
    property bool charging: false
    // "glances", "animation" or "nothing".
    property string idleMode: "glances"
    property var glances: ({ events: true, battery: true, time: true, weather: true, updates: false, todo: true })
    // Repo packages waiting for an update; -1 while unknown.
    property int updates: -1
    // A file URL, or "builtin:<name>" for one of IdleArt's animations.
    property string idleAnimation: "builtin:aurora"
    property bool animateOnHoverOnly: true
    // Nobody is using the computer, so nobody is watching the animation.
    property bool userIdle: false
    property int glanceTick: 0
    readonly property var glance: {
        // Read only so refreshGlance() re-evaluates this binding.
        glanceTick
        const next = calendar && calendar.upNext ? calendar.upNext(1) : []
        return L.idleGlance({
            now: now(), show: glances, event: next.length ? next[0] : null,
            battery: battery, charging: charging,
            temperature: weather ? weather.temperature : NaN, updates: updates,
            todo: todos && todos.nextOpen && todos.nextOpen.id ? todos.nextOpen : null
        })
    }
    function refreshGlance() { glanceTick++ }
    signal settingsRequested()
    signal notificationClicked(string desktopEntry)
    // First-run tour: a card per step of L.TOUR, until finished or skipped.
    property bool tourActive: false
    property int tourStep: 0
    signal tourFinished()
    function startTour() {
        open = false
        menuOpen = false
        tourStep = 0
        tourActive = true
    }
    function nextTourStep() {
        if (tourStep + 1 < L.TOUR.length) {
            tourStep++
        } else {
            tourActive = false
            tourFinished()
        }
    }
    function skipTour() {
        tourActive = false
        tourFinished()
    }

    // Right-click menu. Its timer rows start the timer here; the rest go out as menuAction(key).
    property bool menuOpen: false
    property bool dnd: false
    // Folded into a sliver at the top edge, like behind a full-screen app, until shown again.
    property bool hiddenByUser: false
    readonly property var menuRows: L.pillMenu({ dnd: dnd, hidden: hiddenByUser })
    signal menuAction(string key)
    function pickMenu(key, minutes) {
        menuOpen = false
        if (key === "timers") {
            if (timer)
                timer.start(minutes)
            return
        }
        menuAction(key)
    }
    // One of a notification's own actions: a button on its alert, or "default" for a click on it.
    signal notificationAction(int serverId, string key)
    // Scrolling up or down over the closed pill: steps of 5% speaker volume, positive is louder.
    signal volumeStep(int steps)
    signal linkRequested(string url)

    // A short alert (volume, notification, device, charger, colour) that takes over the closed pill.
    property var alert: null
    function showAlert(a, ms) {
        sliverWidth = L.alertSize(a.kind, barHeight, cornerRadius, a).w * 0.4
        alert = a
        alertTimer.interval = ms
        alertTimer.restart()
    }
    // Opened with Meta+N: the pointer is usually elsewhere, so hover-out only closes it once
    // the pointer has been on the panel (touched).
    property bool openedByKeyboard: false
    property bool touched: false
    function toggleFromKeyboard() {
        if (open) {
            open = false
            return
        }
        openedByKeyboard = true
        open = true
    }
    onHoveredChanged: if (open && hovered) touched = true
    onOpenChanged: {
        if (!open) {
            openedByKeyboard = false
            touched = false
        }
        if (open) {
            alert = null
            menuOpen = false
        } else {
            requestedTab = ""
            if (flyer.visible)
                landCover()
        }
    }
    Timer {
        id: alertTimer
        // A notification stays while the pointer is on it.
        onTriggered: island.hovered && island.alert && island.alert.kind === "notification" ? restart() : island.alert = null
    }

    property var micApps: []
    property var cameraApps: []
    // File URLs dropped on the island, held until dragged out or removed.
    property var shelf: []
    property var links: []
    property var colors: []
    signal colorPickRequested()
    signal copyRequested(string text)
    property string requestedTab: ""
    function addToShelf(urls) {
        shelf = shelf.concat(urls.filter(u => !shelf.includes(u)))
        extraTool = "shelf"
        requestedTab = "shelf"
        open = true
        if (panelLoader.item)
            panelLoader.item.tab = "shelf"
    }
    readonly property bool showIndicators: micApps.length > 0 || cameraApps.length > 0 || shelf.length > 0
    readonly property real indicatorWidth: showIndicators ? indicators.implicitWidth + 10 : 0
    readonly property bool cyclePaused: swipePause.running
    property int wheelAccum: 0
    property bool swipeUsed: false
    readonly property string mode: L.islandState(activities.length > 0, hovered, open, alert !== null, menuOpen, tourActive)
    readonly property bool playing: player !== null && player.playbackStatus === L.Status.Playing

    readonly property var sizes: ({
        idle: { w: (idleMode !== "glances" ? idleWidth
                    : glance.kind === "event" ? Math.max(idleWidth, glance.link ? 290 : 230)
                    : glance.kind === "todo" ? Math.max(idleWidth, 250)
                    : glance.kind === "clock" && glance.showBattery && glance.showTime && glance.showWeather ? Math.max(idleWidth, 200) + (glance.updates > 0 ? 44 : 0)
                    : glance.kind === "clock" && glance.updates > 0 ? idleWidth + 44
                    : idleWidth) + indicatorWidth + historyChipWidth, h: barHeight, r: cornerRadius },
        compact: { w: compactWidth + indicatorWidth, h: barHeight, r: cornerRadius },
        peek: activity === "jobs" ? { w: 360, h: 22 + jobRows * 42, r: 20 } : { w: 330, h: 60, r: 20 },
        // 14 + 18: panelLoader's top and bottom margins.
        tour: { w: 420, h: 116, r: 26 },
        menu: { w: 290, h: 16 + menuRows.length * 36, r: 22 },
        open: { w: 860, h: panelLoader.item && panelLoader.item.fitHeight > 0 ? panelLoader.item.fitHeight + 14 + 18 : 420, r: 30 }
    })
    // Behind a full-screen app the pill folds into a sliver at the top edge; an alert grows out of it.
    property bool coveredByFullScreen: false
    property real sliverWidth: 120
    readonly property bool tucked: (coveredByFullScreen || hiddenByUser) && (mode === "idle" || mode === "compact" || mode === "peek")
    readonly property var size: mode === "alert" ? L.alertSize(alert.kind, barHeight, cornerRadius, alert)
                              : tucked ? { w: sliverWidth, h: 0, r: 6 }
                              : sizes[mode]
    // In front of the full-screen app while it has something to show, until it has folded away.
    readonly property bool wantsFront: coveredByFullScreen && (open || alert !== null || height > 0.5)
    // Where the island sits in its parent; the window's input region must track position too, not just size.
    readonly property rect inputRect: Qt.rect(x, y, width, height)

    width: size.w
    height: size.h
    // Tucked behind a full-screen app the pill is a zero-height sliver; its contents mustn't spill out.
    clip: tucked

    // Folding away uses no spring, so it never dips below the top edge.
    Behavior on width { NumberAnimation { duration: island.tucked ? 260 : 350; easing.type: island.tucked ? Easing.InCubic : Easing.OutBack; easing.overshoot: 1.2 } }
    Behavior on height { NumberAnimation { duration: island.tucked ? 260 : 350; easing.type: island.tucked ? Easing.InCubic : Easing.OutBack; easing.overshoot: 1.2 } }

    // The position timer only runs while playing, so fetch once on open.
    onModeChanged: {
        if ((mode === "open" || mode === "peek") && player && player.updatePosition)
            player.updatePosition()
        // Whether the cover was on the pill just before the panel opened, for its flight in.
        if (mode !== "open" && mode !== "alert")
            musicWasShown = musicShown
    }

    function step(dir) {
        if (activities.length > 1)
            current = ((current + dir) % activities.length + activities.length) % activities.length
    }

    HoverHandler { id: hover }

    // Keeps the clock and "in N min" current; cheap enough not to align to the minute.
    Timer {
        interval: 15000
        repeat: true
        running: island.mode === "idle" && island.idleMode === "glances"
        onTriggered: island.refreshGlance()
    }
    Connections {
        target: island.calendar && island.calendar.changed ? island.calendar : null
        ignoreUnknownSignals: true
        function onChanged() { island.refreshGlance() }
    }

    Timer {
        interval: island.cycleInterval
        repeat: true
        running: island.activities.length > 1 && island.mode === "compact" && !island.cyclePaused
        onTriggered: island.step(1)
    }

    // A swipe holds the chosen activity on screen for a while before cycling resumes.
    Timer {
        id: swipePause
        interval: island.swipeHold
    }

    // A swipe ends once wheel events stop for a moment; until then it can step only once.
    Timer {
        id: swipeEnd
        interval: 250
        onTriggered: {
            island.swipeUsed = false
            island.wheelAccum = 0
        }
    }

    // Layer-shell surfaces get no clicks outside their input region, so the open
    // island closes when the pointer stays away for a moment instead.
    Timer {
        interval: 300
        running: island.openOnHover && island.hovered && !island.open && !island.menuOpen
        onTriggered: island.open = true
    }

    // The menu closes once the pointer has left it for a moment.
    Timer {
        interval: 500
        running: island.menuOpen && !island.hovered
        onTriggered: island.menuOpen = false
    }

    Timer {
        id: closeTimer
        interval: 600
        // Stays open while typing a note or a search, even with the pointer elsewhere.
        running: island.open && !island.hovered && !(panelLoader.item && panelLoader.item.typing)
                 && (!island.openedByKeyboard || island.touched)
        onTriggered: island.open = false
    }

    Timer {
        interval: 1000
        repeat: true
        // The music peek has a seek bar too.
        running: (island.mode === "open" || island.musicShown && island.mode === "peek") && island.playing
        onTriggered: island.player.updatePosition()
    }

    // Notch: flush with the screen top, with small curves into the panel. Pill: four rounded corners.
    // Switching shrinks the curves away first, then rounds the top corners.
    Shape {
        id: notch
        objectName: "islandShape"
        // 0 is notch, 1 is pill.
        property real p: island.pill ? 1 : 0
        Behavior on p { NumberAnimation { duration: 450; easing.type: Easing.InOutCubic } }
        property real notchR: island.size.r
        property real pillR: Math.min(island.size.h / 2, Math.max(island.size.r, island.barHeight / 2))
        Behavior on notchR { NumberAnimation { duration: 350 } }
        Behavior on pillR { NumberAnimation { duration: 350 } }
        readonly property real r: notchR + (pillR - notchR) * p
        readonly property real ear: island.earSize * Math.max(0, 1 - 2 * p)
        readonly property real topR: r * Math.max(0, 2 * p - 1)
        // Only one of the two is ever non-zero, so one arc serves both.
        readonly property real corner: ear + topR
        readonly property int turn: topR > 0 ? PathArc.Clockwise : PathArc.Counterclockwise
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "#000000"
            // A thin edge in the cover's colour while the music turn shows.
            strokeWidth: island.coverTinted && island.musicShown ? 1 : -1
            strokeColor: Qt.rgba(island.coverTint.r, island.coverTint.g, island.coverTint.b, 0.55)
            startX: notch.topR - notch.ear; startY: 0
            PathLine { x: island.width + notch.ear - notch.topR; y: 0 }
            PathArc { x: island.width; y: notch.corner; radiusX: notch.corner; radiusY: notch.corner; direction: notch.turn }
            PathLine { x: island.width; y: island.height - notch.r }
            PathArc { x: island.width - notch.r; y: island.height; radiusX: notch.r; radiusY: notch.r }
            PathLine { x: notch.r; y: island.height }
            PathArc { x: 0; y: island.height - notch.r; radiusX: notch.r; radiusY: notch.r }
            PathLine { x: 0; y: notch.corner }
            PathArc { x: notch.topR - notch.ear; y: 0; radiusX: notch.corner; radiusY: notch.corner; direction: notch.turn }
        }
    }

    // A click on the music turn waits this long for a second click, which skips the song.
    property int doubleClickMs: 250
    readonly property bool musicShown: activity === "music" && player !== null && (mode === "compact" || mode === "peek")
    property real verticalAccum: 0
    Timer {
        id: clickDelay
        interval: island.doubleClickMs
        onTriggered: island.open = true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton && clickDelay.running) {
                clickDelay.stop()
                if (island.player.canGoNext !== false)
                    island.player.Next()
            }
        }
        onClicked: mouse => {
            if (island.mode === "tour")
                return
            if (mouse.button === Qt.RightButton) {
                if (!island.open) {
                    clickDelay.stop()
                    island.menuOpen = !island.menuOpen
                }
                return
            }
            if (island.mode === "menu") {
                island.menuOpen = false
                return
            }
            if (mouse.button === Qt.MiddleButton) {
                if (island.player && !island.open)
                    island.player.PlayPause()
                return
            }
            if (island.mode === "alert" && island.alert.kind === "notification") {
                // The app's own default action opens the right chat or page; otherwise just the app.
                if (island.alert.hasDefault && island.alert.serverId > 0)
                    island.notificationAction(island.alert.serverId, "default")
                else
                    island.notificationClicked(island.alert.desktopEntry)
                island.alert = null
                return
            }
            if (island.mode === "alert" && island.alert.kind === "job") {
                if (island.alert.ok && island.alert.folder)
                    island.linkRequested(island.alert.folder)
                island.alert = null
                return
            }
            if (island.musicShown) {
                clickDelay.restart()
                return
            }
            island.open = true
        }
        onWheel: wheel => {
            if (island.open) {
                wheel.accepted = false
                return
            }
            // Up and down: volume, or minutes on the timer's turn. Sideways: switch turns.
            if (Math.abs(wheel.angleDelta.y) > Math.abs(wheel.angleDelta.x)) {
                const v = L.wheelSteps(island.verticalAccum, wheel.angleDelta.y)
                island.verticalAccum = v.accum
                if (v.steps === 0)
                    return
                if (island.activity === "timer" && island.timerActive && (island.mode === "compact" || island.mode === "peek")) {
                    const t = island.timer
                    const add = L.timerStepMinutes(t.paused ? t.pausedRemainingMs : t.remainingMs, v.steps)
                    if (add !== 0)
                        t.addMinutes(add)
                } else {
                    island.volumeStep(v.steps)
                }
                return
            }
            swipeEnd.restart()
            if (island.swipeUsed)
                return
            const r = L.wheelSteps(island.wheelAccum, -wheel.angleDelta.x)
            island.wheelAccum = r.accum
            if (r.steps !== 0) {
                island.swipeUsed = true
                island.step(r.steps > 0 ? 1 : -1)
                swipePause.restart()
            }
        }
    }

    Slide {
        shown: island.mode === "idle" && island.idleMode !== "nothing"

        Row {
            objectName: "glanceRow"
            visible: island.idleMode === "glances" && island.glance.kind !== "none"
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -(island.indicatorWidth + island.historyChipWidth) / 2 - (batteryRing.visible ? 10 : 0)
            spacing: 7
            readonly property string kind: island.glance.kind
            readonly property color tint: kind === "event" ? palette.accent : kind === "batteryLow" ? "#ff6b6b" : "#ffffff"

            // The next task: tick the circle to mark it done.
            Rectangle {
                objectName: "glanceTodoCheck"
                visible: parent.kind === "todo"
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: todoCheckArea.containsMouse ? palette.accent : "transparent"
                border.color: palette.accent
                border.width: 1.5
                Text {
                    anchors.centerIn: parent
                    visible: todoCheckArea.containsMouse
                    text: "✓"
                    color: "#ffffff"
                    font.pixelSize: 9
                }
                MouseArea {
                    id: todoCheckArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: island.todoDone(island.glance.id)
                }
            }
            Kirigami.Icon {
                visible: parent.kind !== "clock" && parent.kind !== "todo"
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: parent.kind === "event" ? "view-calendar"
                      : "battery-010"
                color: parent.tint
                isMask: true
            }
            Text {
                objectName: "glanceTitle"
                visible: parent.kind !== "clock"
                width: Math.min(implicitWidth, island.width - 110 - island.historyChipWidth)
                anchors.verticalCenter: parent.verticalCenter
                text: island.glance.title || ""
                color: parent.kind === "batteryLow" ? "#ff8a8a" : "#ffffff"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
            }
            Text {
                objectName: "glanceDetail"
                visible: parent.kind !== "clock"
                anchors.verticalCenter: parent.verticalCenter
                text: island.glance.detail || ""
                color: "#9aa3ad"
                font.pixelSize: 12
            }

            Rectangle {
                objectName: "glanceJoin"
                visible: parent.kind === "event" && !!island.glance.link && island.glances.meetings !== false
                anchors.verticalCenter: parent.verticalCenter
                width: joinText.implicitWidth + 20
                height: 20
                radius: 10
                color: joinArea.containsMouse ? Qt.lighter(palette.accent, 1.15) : palette.accent
                Text {
                    id: joinText
                    anchors.centerIn: parent
                    text: "Join"
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: joinArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: island.linkRequested(island.glance.link)
                }
            }

            Text {
                objectName: "glanceTime"
                visible: parent.kind === "clock" && island.glance.showTime
                anchors.verticalCenter: parent.verticalCenter
                text: island.glance.time || ""
                color: "#ffffff"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Rectangle {
                visible: parent.kind === "clock" && island.glance.showTime && island.glance.showWeather
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 12
                color: "#333333"
            }
            Kirigami.Icon {
                visible: parent.kind === "clock" && island.glance.showWeather
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: W.describe(island.weather ? island.weather.code : -1).icon
                color: "#ffffff"
                isMask: true
            }
            Text {
                objectName: "glanceWeather"
                visible: parent.kind === "clock" && island.glance.showWeather
                anchors.verticalCenter: parent.verticalCenter
                text: island.weather ? island.weather.temperature + "°" : ""
                color: "#ffffff"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Rectangle {
                visible: parent.kind === "clock" && island.glance.updates > 0 && (island.glance.showTime || island.glance.showWeather)
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 12
                color: "#333333"
            }
            Kirigami.Icon {
                visible: parent.kind === "clock" && island.glance.updates > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: "update-none"
                fallback: "view-refresh"
                color: "#ffffff"
                isMask: true
            }
            Text {
                objectName: "glanceUpdates"
                visible: parent.kind === "clock" && island.glance.updates > 0
                anchors.verticalCenter: parent.verticalCenter
                text: island.glance.updates || ""
                color: "#ffffff"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }

        // Battery level as a ring at the right end; green while plugged in.
        Shape {
            id: batteryRing
            objectName: "batteryRing"
            visible: island.idleMode === "glances" && island.glance.kind === "clock" && !!island.glance.showBattery
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 12 + island.indicatorWidth
            width: 14
            height: 14
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: "#2b2f35"
                strokeWidth: 2.2
                PathAngleArc { centerX: 7; centerY: 7; radiusX: 5.5; radiusY: 5.5; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: island.charging ? "#30d158" : "#ffffff"
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 7; centerY: 7; radiusX: 5.5; radiusY: 5.5
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0, Math.min(100, island.battery)) / 100
                    Behavior on sweepAngle { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
            }
        }

        // Same shape as the jobs chip, in amber, so new notifications never read as a download or the battery.
        Rectangle {
            id: historyChip
            objectName: "historyChip"
            visible: island.showHistoryChip
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: batteryRing.visible ? batteryRing.left : parent.right
            anchors.rightMargin: batteryRing.visible ? 8 : 12 + island.indicatorWidth
            width: historyRow.implicitWidth + 12
            height: 18
            radius: 9
            color: "#33270f"
            Row {
                id: historyRow
                anchors.centerIn: parent
                spacing: 4
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 11
                    height: 11
                    source: "notifications"
                    color: "#ffb340"
                    isMask: true
                }
                Text {
                    objectName: "historyChipText"
                    anchors.verticalCenter: parent.verticalCenter
                    text: island.newNotifications
                    color: "#ffb340"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }

        IdleArt {
            objectName: "idleArt"
            visible: island.idleMode === "animation" && island.idleAnimation.startsWith("builtin:")
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            name: visible ? island.idleAnimation.slice(8) : ""
            playing: visible && !island.userIdle && (!island.animateOnHoverOnly || island.hovered)
        }

        AnimatedImage {
            objectName: "idleAnimation"
            visible: island.idleMode === "animation" && !island.idleAnimation.startsWith("builtin:")
            anchors.centerIn: parent
            width: island.width - 24
            height: island.height - 8
            fillMode: Image.PreserveAspectFit
            source: visible ? island.idleAnimation : ""
            // Playing all day keeps the GPU awake, so by default it only plays under the pointer.
            playing: visible && !island.userIdle && (!island.animateOnHoverOnly || island.hovered)
            asynchronous: true
        }
    }

    readonly property bool showMusic: activity === "music" && (mode === "compact" || mode === "peek")
    readonly property bool showTimer: activity === "timer" && (mode === "compact" || mode === "peek")
    readonly property bool showJobs: activity === "jobs" && (mode === "compact" || mode === "peek")
    readonly property color jobInk: Qt.lighter(palette.accent, 1.45)
    readonly property color jobTile: Qt.rgba(palette.accent.r, palette.accent.g, palette.accent.b, 0.22)
    readonly property string timerText: timerActive ? L.countdownText(timer.paused ? timer.pausedRemainingMs : timer.remainingMs) : ""

    // Jobs never use a circle, so they can't be mistaken for the idle battery ring.
    component JobTile: Rectangle {
        width: 18
        height: 18
        radius: 6
        color: island.jobTile
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 12
            height: 12
            source: "download-symbolic"
            color: island.jobInk
            isMask: true
        }
    }

    // Shown on the music and timer turns while jobs run.
    component JobChip: Rectangle {
        objectName: "jobChip"
        visible: island.jobs.count > 0 && island.mode === "compact"
        anchors.verticalCenter: parent.verticalCenter
        width: chipRow.implicitWidth + 12
        height: 18
        radius: 9
        color: island.jobTile
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                source: "download-symbolic"
                color: island.jobInk
                isMask: true
            }
            Text {
                objectName: "jobChipText"
                anchors.verticalCenter: parent.verticalCenter
                text: (island.jobs.count > 1 ? island.jobs.count + " · " : "") + island.jobs.percent + "%"
                color: island.jobInk
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }

    component Slide: Item {
        id: slide
        property bool shown
        anchors.fill: parent
        opacity: shown ? 1 : 0
        visible: opacity > 0
        // Old content leaves fast and the new one fades in after it, so they never overlap visibly.
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: slide.shown ? 90 : 0 }
                NumberAnimation { duration: slide.shown ? 180 : 90 }
            }
        }
        transform: Translate {
            x: slide.shown ? 0 : 12
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
    }

    Slide {
        shown: island.showMusic

        CoverArt {
            id: art
            readonly property int side: island.mode === "peek" ? 34 : 18
            width: side
            height: side
            radius: Math.round(side * 0.36)
            x: island.mode === "peek" ? 12 : 8
            y: (island.height - side) / 2
            source: island.player ? island.artUrl : ""
            fallbackIcon: island.player ? island.player.iconName || island.player.desktopEntry || "" : ""
        }

        Bars {
            id: musicBars
            objectName: "bars"
            visible: island.mode === "compact"
            running: island.playing
            level: island.audioLevel
            color: island.coverTinted ? island.coverTint : "#e8e2d0"
            anchors.right: parent.right
            anchors.rightMargin: 10 + island.indicatorWidth
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            visible: island.mode === "peek"
            anchors.left: art.right
            anchors.leftMargin: 10
            anchors.right: peekPlayPause.left
            anchors.rightMargin: 6
            anchors.verticalCenter: art.verticalCenter

            Text {
                objectName: "title"
                width: parent.width
                text: island.player ? island.player.track : ""
                color: "#ffffff"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                objectName: "artist"
                width: parent.width
                text: island.player ? island.player.artist : ""
                color: "#9aa3ad"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        // A thin seek bar along the bottom of the music peek; drag or click to jump.
        Item {
            id: peekSeek
            objectName: "peekSeek"
            visible: island.mode === "peek" && island.player !== null && island.player.length > 0
            anchors.left: art.left
            anchors.right: peekPlayPause.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            height: 10
            // While dragging, the bar follows the pointer; the player seeks on release.
            property real dragFraction: -1
            readonly property real fraction: dragFraction >= 0 ? dragFraction
                : island.player && island.player.length > 0 ? Math.max(0, Math.min(1, island.player.position / island.player.length)) : 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: seekArea.containsMouse || seekArea.pressed ? 4 : 2
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.18)
                Behavior on height { NumberAnimation { duration: 120 } }
                Rectangle {
                    objectName: "peekSeekFill"
                    width: parent.width * peekSeek.fraction
                    height: parent.height
                    radius: parent.radius
                    color: island.coverTinted ? island.coverTint : "#ffffff"
                }
            }
            Rectangle {
                visible: seekArea.containsMouse || seekArea.pressed
                width: 9
                height: 9
                radius: 4.5
                x: peekSeek.fraction * peekSeek.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: "#ffffff"
            }
            MouseArea {
                id: seekArea
                objectName: "peekSeekArea"
                anchors.fill: parent
                anchors.topMargin: -3
                hoverEnabled: true
                enabled: island.player !== null && island.player.canSeek !== false
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                function fractionAt(x) { return Math.max(0, Math.min(1, x / width)) }
                onPressed: mouse => peekSeek.dragFraction = fractionAt(mouse.x)
                onPositionChanged: mouse => { if (pressed) peekSeek.dragFraction = fractionAt(mouse.x) }
                onReleased: mouse => {
                    island.player.position = Math.round(fractionAt(mouse.x) * island.player.length)
                    peekSeek.dragFraction = -1
                }
                onCanceled: peekSeek.dragFraction = -1
            }
        }

        ControlButton {
            id: peekPlayPause
            objectName: "peekPlayPause"
            visible: island.mode === "peek"
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            iconName: island.playing ? "media-playback-pause" : "media-playback-start"
            onClicked: island.player.PlayPause()
        }

        JobChip {
            anchors.right: musicBars.left
            anchors.rightMargin: 8
        }
    }

    Slide {
        shown: island.showTimer

        Kirigami.Icon {
            id: timerIcon
            readonly property int side: island.mode === "peek" ? 24 : 16
            x: island.mode === "peek" ? 16 : 10
            anchors.verticalCenter: parent.verticalCenter
            width: side
            height: side
            source: "chronometer"
            color: "#ffffff"
            isMask: true
        }

        Text {
            id: timerCountdown
            objectName: "timerText"
            visible: island.mode === "compact"
            anchors.right: parent.right
            anchors.rightMargin: 12 + island.indicatorWidth
            anchors.verticalCenter: parent.verticalCenter
            text: island.timerText
            color: "#e8e2d0"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Column {
            visible: island.mode === "peek"
            anchors.left: timerIcon.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: island.timerActive && island.timer.paused ? "Timer paused" : "Timer"
                color: "#9aa3ad"
                font.pixelSize: 12
            }
            Text {
                objectName: "peekTimerText"
                text: island.timerText
                color: "#ffffff"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }

        ControlButton {
            objectName: "peekTimerToggle"
            visible: island.mode === "peek"
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            iconName: island.timerActive && island.timer.running ? "media-playback-pause" : "media-playback-start"
            onClicked: island.timer.running ? island.timer.pause() : island.timer.resume()
        }

        JobChip {
            anchors.right: timerCountdown.left
            anchors.rightMargin: 8
        }
    }

    Slide {
        shown: island.showJobs

        JobTile {
            id: jobsTile
            visible: island.mode === "compact"
            x: 8
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            objectName: "jobsTitle"
            visible: island.mode === "compact"
            anchors.left: jobsTile.right
            anchors.leftMargin: 8
            anchors.right: jobsPercent.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: island.jobs.count === 1 ? L.jobName(island.jobs.shown[0]) : island.jobs.count + " jobs"
            color: "#ffffff"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            id: jobsPercent
            objectName: "jobsPercent"
            visible: island.mode === "compact"
            anchors.right: parent.right
            anchors.rightMargin: 12 + island.indicatorWidth
            anchors.verticalCenter: parent.verticalCenter
            text: island.jobs.percent + "%"
            color: "#9aa3ad"
            font.pixelSize: 12
            font.features: { "tnum": 1 }
        }
        // Combined progress along the bottom edge.
        Rectangle {
            visible: island.mode === "compact"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 1
            height: 2
            radius: 1
            color: "#24282d"
            Rectangle {
                objectName: "jobsLine"
                width: parent.width * island.jobs.percent / 100
                height: parent.height
                radius: 1
                color: palette.accent
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        Column {
            objectName: "jobsList"
            visible: island.mode === "peek"
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            Repeater {
                model: island.mode === "peek" ? island.jobs.shown.slice(0, island.jobs.count > 4 ? 3 : 4) : []
                delegate: Item {
                    id: row
                    required property var modelData
                    width: parent.width
                    height: 42
                    JobTile { id: rowTile; y: 2 }
                    Column {
                        anchors.left: rowTile.right
                        anchors.leftMargin: 10
                        anchors.right: rowPercent.left
                        anchors.rightMargin: 10
                        spacing: 3
                        Text {
                            width: parent.width
                            text: L.jobName(row.modelData)
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            readonly property string timeLeft: L.jobTimeLeft(row.modelData)
                            width: parent.width
                            text: island.jobs.count === 1 && row.modelData.totalBytes > 0
                                  ? L.formatSize(row.modelData.processedBytes || 0) + " of " + L.formatSize(row.modelData.totalBytes)
                                    + (row.modelData.speed > 0 ? " · " + L.formatSize(row.modelData.speed) + "/s" : "") + (timeLeft ? " · " + timeLeft + " left" : "")
                                  : L.jobVerb(row.modelData) + (timeLeft ? " · " + timeLeft + " left" : "")
                            color: "#9aa3ad"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            width: parent.width
                            height: 3
                            radius: 1.5
                            color: "#24282d"
                            Rectangle {
                                width: parent.width * (row.modelData.percent || 0) / 100
                                height: parent.height
                                radius: 1.5
                                color: palette.accent
                            }
                        }
                    }
                    Text {
                        id: rowPercent
                        anchors.right: parent.right
                        y: 4
                        text: (row.modelData.percent || 0) + "%"
                        color: "#9aa3ad"
                        font.pixelSize: 12
                        font.features: { "tnum": 1 }
                    }
                }
            }
            Text {
                objectName: "jobsMore"
                visible: island.jobs.count > 4
                height: 30
                verticalAlignment: Text.AlignVCenter
                leftPadding: 28
                text: "+" + (island.jobs.count - 3) + " more"
                color: "#9aa3ad"
                font.pixelSize: 12
            }
        }
    }

    Row {
        objectName: "dots"
        visible: island.activities.length > 1 && island.mode === "compact"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        spacing: 4
        Repeater {
            model: island.activities.length
            delegate: Rectangle {
                id: dot
                required property int index
                width: 4
                height: 4
                radius: 2
                color: dot.index === island.current % island.activities.length ? "#ffffff" : "#5a616a"
            }
        }
    }

    Slide {
        shown: island.mode === "tour"
        readonly property var step: L.TOUR[Math.min(island.tourStep, L.TOUR.length - 1)]
        Kirigami.Icon {
            id: tourIcon
            x: 18
            y: 18
            width: 28
            height: 28
            source: parent.step.icon
            color: palette.accent
            isMask: true
        }
        Column {
            anchors.left: tourIcon.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 14
            spacing: 3
            Text {
                objectName: "tourTitle"
                width: parent.width
                text: parent.parent.step.title
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                objectName: "tourBody"
                width: parent.width
                text: parent.parent.step.body
                color: "#c4cad1"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
        Row {
            x: 18 + 28 + 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            spacing: 5
            Repeater {
                model: L.TOUR.length
                delegate: Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: index === island.tourStep ? 14 : 6
                    height: 6
                    radius: 3
                    color: index === island.tourStep ? "#ffffff" : Qt.rgba(1, 1, 1, 0.3)
                    Behavior on width { NumberAnimation { duration: 150 } }
                }
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            spacing: 6
            Rectangle {
                objectName: "tourSkip"
                visible: island.tourStep + 1 < L.TOUR.length
                width: skipText.implicitWidth + 22
                height: 26
                radius: 13
                color: skipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                Text { id: skipText; anchors.centerIn: parent; text: "Skip"; color: "#9aa3ad"; font.pixelSize: 12 }
                MouseArea { id: skipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: island.skipTour() }
            }
            Rectangle {
                objectName: "tourNext"
                width: nextText.implicitWidth + 26
                height: 26
                radius: 13
                color: nextArea.containsMouse ? Qt.lighter(palette.accent, 1.15) : palette.accent
                Text {
                    id: nextText
                    anchors.centerIn: parent
                    text: island.tourStep + 1 < L.TOUR.length ? "Next" : "Got it"
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: island.nextTourStep() }
            }
        }
    }

    component MenuRow: Rectangle {
        id: row
        property string icon
        property string label
        signal picked()
        width: parent ? parent.width : 0
        height: 32
        radius: 10
        color: rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
        Kirigami.Icon {
            id: rowIcon
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: row.icon
            color: "#ffffff"
            isMask: true
        }
        Text {
            anchors.left: rowIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: "#ffffff"
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked()
        }
    }

    Slide {
        shown: island.mode === "menu"
        Column {
            objectName: "pillMenu"
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            Repeater {
                model: island.mode === "menu" ? island.menuRows : []
                delegate: Item {
                    id: entry
                    required property var modelData
                    width: parent.width
                    height: 32
                    MenuRow {
                        visible: !entry.modelData.minutes
                        objectName: "menu-" + entry.modelData.key
                        icon: entry.modelData.icon
                        label: entry.modelData.label
                        onPicked: island.pickMenu(entry.modelData.key)
                    }
                    // Timer presets sit side by side on one row.
                    Row {
                        visible: !!entry.modelData.minutes
                        anchors.fill: parent
                        spacing: 6
                        Kirigami.Icon {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            source: entry.modelData.icon
                            color: "#ffffff"
                            isMask: true
                        }
                        Item { width: 4; height: 1 }
                        Repeater {
                            model: entry.modelData.minutes || []
                            delegate: Rectangle {
                                required property int modelData
                                objectName: "menu-timer-" + modelData
                                anchors.verticalCenter: parent.verticalCenter
                                width: 64
                                height: 26
                                radius: 13
                                color: chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.1)
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData + " min"
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: island.pickMenu("timers", parent.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    AlertView {
        alert: island.alert
        shown: island.mode === "alert"
        onButtonClicked: key => {
            if (island.alert && island.alert.serverId > 0)
                island.notificationAction(island.alert.serverId, key)
            island.alert = null
        }
    }

    // Mic and camera dots, plus the shelf count; they sit at the right end of the closed pill.
    Row {
        id: indicators
        objectName: "indicators"
        visible: island.showIndicators && (island.mode === "idle" || island.mode === "compact")
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        HoverHandler { id: indicatorHover }
        QQC.ToolTip.visible: indicatorHover.hovered && L.privacyText(island.micApps, island.cameraApps) !== ""
        QQC.ToolTip.text: L.privacyText(island.micApps, island.cameraApps)
        QQC.ToolTip.delay: 300

        Row {
            visible: island.shelf.length > 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                source: "folder-download-symbolic"
                color: "#9aa3ad"
                isMask: true
            }
            Text {
                objectName: "shelfCount"
                anchors.verticalCenter: parent.verticalCenter
                text: island.shelf.length
                color: "#9aa3ad"
                font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
        }
        Rectangle {
            objectName: "micDot"
            visible: island.micApps.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: "#ff9f0a"
        }
        Rectangle {
            objectName: "cameraDot"
            visible: island.cameraApps.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: "#30d158"
        }
    }

    DropArea {
        anchors.fill: parent
        onEntered: drag => drag.accepted = drag.hasUrls && !island.open
        onDropped: drop => island.addToShelf(drop.urls.map(u => String(u)))
    }

    // Opening from the music turn: the pill's cover flies to its place in the panel while the
    // island grows. It lives on the window, so the centred island's growth doesn't drag it.
    property bool animateOpen: true
    Item {
        id: flyer
        objectName: "coverFlyer"
        parent: island.parent
        z: 1000
        visible: false
        property real progress: 0
        property int frame: 0
        property rect from: Qt.rect(0, 0, 0, 0)
        property var target: null
        // Re-read every frame: the panel's layout keeps moving while the island grows.
        readonly property rect to: {
            progress
            frame
            if (!target || !target.width)
                return from
            const p = target.mapToItem(flyer.parent, 0, 0)
            return Qt.rect(p.x, p.y, target.width, target.height)
        }
        x: from.x + (to.x - from.x) * progress
        y: from.y + (to.y - from.y) * progress
        width: from.width + (to.width - from.width) * progress
        height: width
        CoverArt {
            anchors.fill: parent
            radius: Math.round(width * 0.2)
            source: island.player ? island.artUrl : ""
            fallbackIcon: island.player ? island.player.iconName || island.player.desktopEntry || "" : ""
        }
        NumberAnimation on progress {
            id: flight
            running: false
            from: 0
            to: 1
            duration: 380
            easing.type: Easing.OutCubic
        }
        FrameAnimation {
            running: flyer.visible
            onTriggered: {
                flyer.frame++
                // Lands once it has arrived and the island has stopped growing.
                if (!flight.running && island.width === island.size.w && island.height === island.size.h)
                    island.landCover()
            }
        }
    }
    function landCover() {
        // Freeze where it landed, letting go of the panel's cover (it goes when the panel closes).
        flyer.from = flyer.to
        flyer.progress = 0
        flyer.target = null
        flyer.visible = false
        if (panelLoader.item)
            panelLoader.item.coverHidden = false
    }
    property bool musicWasShown: false
    onMusicShownChanged: if (musicShown) musicWasShown = true
    function flyCoverIn() {
        if (!animateOpen || !musicWasShown || !panelLoader.item || !island.parent)
            return
        const target = panelLoader.item.coverTarget()
        if (!target)
            return
        const p = art.mapToItem(island.parent, 0, 0)
        flyer.from = Qt.rect(p.x, p.y, art.width, art.height)
        flyer.target = target
        flyer.progress = 0
        panelLoader.item.coverHidden = true
        flyer.visible = true
        flight.restart()
    }

    Loader {
        id: panelLoader
        active: island.open
        onLoaded: island.flyCoverIn()
        focus: true
        anchors.fill: parent
        anchors.margins: 18
        anchors.topMargin: 14
        sourceComponent: HomePanel {
            tab: island.requestedTab || "home"
            onCloseRequested: island.open = false
            showJoin: island.glances.meetings !== false
            onLinkRequested: url => {
                island.open = false
                island.linkRequested(url)
            }
            shelf: island.shelf
            onShelfChanged: island.shelf = shelf
            links: island.links
            colors: island.colors
            onColorPickRequested: {
                island.open = false
                island.colorPickRequested()
            }
            onCopyRequested: text => island.copyRequested(text)
            clipboard: island.clipboard
            notes: island.notes
            todos: island.todos
            lyrics: island.lyrics
            history: island.history
            newNotifications: island.newNotifications
            onNotificationsLeft: island.notificationsLeft()
            onNotificationClicked: entry => {
                island.open = false
                island.notificationClicked(entry)
            }
            extraTool: island.extraTool
            onExtraToolChanged: island.extraTool = extraTool
            player: island.player
            artUrl: island.artUrl
            musicTint: island.coverTinted ? island.coverTint : "#e8e2d0"
            accentTint: island.musicTint
            timer: island.timer
            weather: island.weather
            calendar: island.calendar
            showQuickButtons: island.systemControls
            quickHidden: island.quickHidden
            showTime: island.panelTime
            showDate: island.panelDate
            sound: island.sound
            onSettingsRequested: {
                island.open = false
                island.settingsRequested()
            }
        }
    }
}
