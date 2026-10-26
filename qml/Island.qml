import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "logic.js" as L
import "weather.js" as W

Item {
    id: island

    property var player: null
    property var timer: null
    property var weather: null
    property var calendar: null
    property var sound: null
    property var clipboard: null
    property var notes: null
    // NotificationHistory for the Notifications tab, and its new count for the tab's badge.
    property var history: null
    property int newNotifications: 0
    // The amber chip only joins the glances: an animation or an empty pill stays as it is.
    readonly property bool showHistoryChip: mode === "idle" && idleMode === "glances" && newNotifications > 0
    readonly property real historyChipWidth: showHistoryChip ? historyChip.width + 8 : 0
    signal notificationsLeft()
    property string extraTool: "clipboard"
    // The clipboard and notes tabs need typing; the rest of the time the island never takes the keyboard.
    readonly property bool wantsKeyboard: open && panelLoader.item !== null && panelLoader.item.wantsKeyboard
    property bool systemControls: true
    property bool open: false
    readonly property bool hovered: hover.hovered
    // Not named `state`: Item already has a `state` property.
    readonly property bool timerActive: timer !== null && (timer.running || timer.paused)
    readonly property var activities: L.activities(player !== null, timerActive, jobs.count > 0)
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
    property var glances: ({ events: true, battery: true, time: true, weather: true })
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
            temperature: weather ? weather.temperature : NaN
        })
    }
    function refreshGlance() { glanceTick++ }
    signal settingsRequested()
    signal notificationClicked(string desktopEntry)
    signal linkRequested(string url)

    // A short alert (volume, notification, device, charger, colour) that takes over the closed pill.
    property var alert: null
    function showAlert(a, ms) {
        sliverWidth = L.alertSize(a.kind, barHeight, cornerRadius).w * 0.4
        alert = a
        alertTimer.interval = ms
        alertTimer.restart()
    }
    onOpenChanged: {
        if (open)
            alert = null
        else
            requestedTab = ""
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
    readonly property string mode: L.islandState(activities.length > 0, hovered, open, alert !== null)
    readonly property bool playing: player !== null && player.playbackStatus === L.Status.Playing

    readonly property var sizes: ({
        idle: { w: (idleMode !== "glances" ? idleWidth
                    : glance.kind === "event" ? Math.max(idleWidth, glance.link ? 290 : 230)
                    : glance.kind === "clock" && glance.showBattery && glance.showTime && glance.showWeather ? Math.max(idleWidth, 200)
                    : idleWidth) + indicatorWidth + historyChipWidth, h: barHeight, r: cornerRadius },
        compact: { w: compactWidth + indicatorWidth, h: barHeight, r: cornerRadius },
        peek: activity === "jobs" ? { w: 360, h: 22 + jobRows * 42, r: 20 } : { w: 330, h: 60, r: 20 },
        // 14 + 18: panelLoader's top and bottom margins.
        open: { w: 860, h: panelLoader.item && panelLoader.item.fitHeight > 0 ? panelLoader.item.fitHeight + 14 + 18 : 420, r: 30 }
    })
    // Behind a full-screen app the pill folds into a sliver at the top edge; an alert grows out of it.
    property bool coveredByFullScreen: false
    property real sliverWidth: 120
    readonly property bool tucked: coveredByFullScreen && (mode === "idle" || mode === "compact" || mode === "peek")
    readonly property var size: mode === "alert" ? L.alertSize(alert.kind, barHeight, cornerRadius)
                              : tucked ? { w: sliverWidth, h: 0, r: 6 }
                              : sizes[mode]
    // In front of the full-screen app while it has something to show, until it has folded away.
    readonly property bool wantsFront: coveredByFullScreen && (open || alert !== null || height > 0.5)
    // Where the island sits in its parent; the window's input region must track position too, not just size.
    readonly property rect inputRect: Qt.rect(x, y, width, height)

    width: size.w
    height: size.h

    // Folding away uses no spring, so it never dips below the top edge.
    Behavior on width { NumberAnimation { duration: island.tucked ? 260 : 350; easing.type: island.tucked ? Easing.InCubic : Easing.OutBack; easing.overshoot: 1.2 } }
    Behavior on height { NumberAnimation { duration: island.tucked ? 260 : 350; easing.type: island.tucked ? Easing.InCubic : Easing.OutBack; easing.overshoot: 1.2 } }

    // The position timer only runs while playing, so fetch once on open.
    onModeChanged: if (mode === "open" && player) player.updatePosition()

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
        running: island.openOnHover && island.hovered && !island.open
        onTriggered: island.open = true
    }

    Timer {
        id: closeTimer
        interval: 600
        // Stays open while typing a note or a search, even with the pointer elsewhere.
        running: island.open && !island.hovered && !(panelLoader.item && panelLoader.item.typing)
        onTriggered: island.open = false
    }

    Timer {
        interval: 1000
        repeat: true
        running: island.mode === "open" && island.playing
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
            strokeWidth: -1
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

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (island.mode === "alert" && island.alert.kind === "notification") {
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
            island.open = true
        }
        onWheel: wheel => {
            if (island.open || Math.abs(wheel.angleDelta.x) <= Math.abs(wheel.angleDelta.y)) {
                wheel.accepted = false
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

            Kirigami.Icon {
                visible: parent.kind !== "clock"
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
            source: island.player ? island.player.artUrl : ""
            fallbackIcon: island.player ? island.player.iconName || island.player.desktopEntry || "" : ""
        }

        Bars {
            id: musicBars
            objectName: "bars"
            visible: island.mode === "compact"
            running: island.playing
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

    AlertView {
        alert: island.alert
        shown: island.mode === "alert"
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

    Loader {
        id: panelLoader
        active: island.open
        anchors.fill: parent
        anchors.margins: 18
        anchors.topMargin: 14
        sourceComponent: HomePanel {
            tab: island.requestedTab || "home"
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
