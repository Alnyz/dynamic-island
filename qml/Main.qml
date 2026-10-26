import QtQuick
import Island
import "logic.js" as L

Window {
    id: root

    width: 900
    height: 460
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint

    function updateInputRegion() {
        InputRegion.set(root, island.inputRect)
    }

    Prefs {
        id: prefs
        location: "file://" + AppConfig.path
    }

    SettingsWindow {
        id: settingsWindow
        prefs: prefs
        calendar: calendarSource
    }

    MprisPlayers { id: mpris }

    SoundSource { id: soundSource }

    ClipboardHistory { id: clipboardHistory }

    NotesStore { id: notesStore }

    NotificationLog { id: notificationLog }

    NotificationHistory {
        id: history
        items: notificationLog.items
        lastSeen: prefs.history.lastSeen
        settings: ({ save: prefs.history.save, system: prefs.history.system, apps: prefs.history.apps, others: prefs.history.others,
                     off: L.toList(prefs.history.off), days: prefs.history.days })
        apps: L.parseKnownApps(prefs.history.known)
        onItemsEdited: items => notificationLog.save(items)
        onAppsEdited: apps => prefs.history.known = JSON.stringify(apps)
        onLastSeenChanged: prefs.history.lastSeen = lastSeen
        Component.onCompleted: prune()
    }

    NotificationWatcher {
        id: notificationWatcher
        onNotified: n => {
            // Saved before the pop-up switch: history keeps notifications even with island pop-ups off.
            history.add(n)
            if (!prefs.show.notifications)
                return
            PlasmaSettings.hidePopupsFor(n.desktopEntry)
            if (!island.open && !SystemStatus.dndActive())
                island.showAlert(Object.assign({ kind: "notification" }, n), 5000)
        }
    }

    BluetoothWatcher {
        onDeviceChanged: d => {
            if (prefs.show.devices && !island.open)
                island.showAlert(Object.assign({ kind: "device" }, d), 4000)
        }
    }

    JobWatcher {
        enabled: prefs.show.jobs
        onUpdated: (key, props) => jobsModel.update(key, props)
        onEnded: (key, code, error) => jobsModel.end(key, code, error)
        onOwnerGone: sender => jobsModel.dropSender(sender)
    }

    JobsModel {
        id: jobsModel
        onFinished: job => {
            if (!SystemStatus.dndActive())
                root.queueAlert({ kind: "job", ok: true, title: L.jobDoneTitle(job), body: job.name, folder: job.folder }, 4000)
        }
        onFailed: (job, error) => root.queueAlert({ kind: "job", ok: false, title: L.jobFailTitle(job), body: job.name + (error ? " · " + error : ""), folder: job.folder }, 4000)
    }
    readonly property bool jobsOn: prefs.show.jobs
    onJobsOnChanged: if (!jobsOn) jobsModel.clear()

    // Job and privacy alerts wait while the panel is open or another alert is up, then play one by one.
    property var queuedAlerts: []
    function queueAlert(a, ms) {
        queuedAlerts = queuedAlerts.concat([{ alert: a, ms: ms }])
        flushAlerts()
    }
    function flushAlerts() {
        if (!queuedAlerts.length || island.open || island.alert !== null)
            return
        const next = queuedAlerts[0]
        queuedAlerts = queuedAlerts.slice(1)
        island.showAlert(next.alert, next.ms)
    }
    Connections {
        target: island
        function onOpenChanged() { root.flushAlerts() }
        function onAlertChanged() { root.flushAlerts() }
    }

    // An alert per app that starts using the mic or camera. Before levelsReady, apps already
    // recording at startup are only remembered.
    property var lastMic: []
    property var lastCamera: []
    function privacyAlerts(now, last, device) {
        if (levelsReady && prefs.show.privacy && !island.open)
            for (const app of L.newApps(last, now))
                queueAlert({ kind: "privacy", app: app, device: device }, 3000)
        return now
    }
    Connections {
        target: soundSource
        function onRecordersChanged() { root.lastMic = root.privacyAlerts(soundSource.recorders, root.lastMic, "microphone") }
    }
    Connections {
        target: cameraWatcher
        function onAppsChanged() { root.lastCamera = root.privacyAlerts(cameraWatcher.apps, root.lastCamera, "camera") }
    }

    CameraWatcher {
        id: cameraWatcher
        enabled: prefs.show.privacy
    }

    // Plasma's own box and popups go away while the island shows the same thing.
    readonly property bool islandLevels: prefs.show.levels
    readonly property bool islandNotifications: prefs.show.notifications
    onIslandLevelsChanged: PlasmaSettings.setOsdEnabled(!islandLevels)
    onIslandNotificationsChanged: PlasmaSettings.setPopupsEnabled(!islandNotifications)

    // Volume reports a burst of changes while the sound devices load at startup.
    property bool levelsReady: false
    Timer {
        interval: 3000
        running: true
        onTriggered: root.levelsReady = true
    }
    // Not shown for the first reading at startup, only for a real plug or unplug.
    readonly property bool plugged: SystemStatus.charging
    onPluggedChanged: if (levelsReady && prefs.show.power && !island.open)
        island.showAlert({ kind: "power", value: SystemStatus.battery, plugged: plugged }, 3000)
    function showLevel(kind, value, muted) {
        if (levelsReady && prefs.show.levels && !island.open)
            island.showAlert({ kind: kind, value: value, muted: muted }, 1500)
    }
    Connections {
        target: soundSource.defaultOutput
        function onVolumeChanged() { root.showLevel("volume", soundSource.defaultOutput.volume / 65536 * 100, soundSource.defaultOutput.muted) }
        function onMutedChanged() { root.showLevel("volume", soundSource.defaultOutput.volume / 65536 * 100, soundSource.defaultOutput.muted) }
    }

    TimerModel {
        id: timerModel
        onFinished: Notifier.timerDone()
    }

    WeatherSource {
        id: weatherSource
        override: prefs.weather.city !== ""
            ? { latitude: prefs.weather.latitude, longitude: prefs.weather.longitude, city: prefs.weather.city }
            : null
        fahrenheit: prefs.weather.fahrenheit
    }

    CalendarSource {
        id: calendarSource
        urls: L.toList(prefs.calendar.icsUrls).filter(u => !L.toList(prefs.calendar.disabled).includes(u))
        refreshMinutes: prefs.calendar.refreshMinutes
    }

    PlayerSource {
        id: source
        players: mpris.list
        pauseTimeoutMs: prefs.behaviour.pausedMinutes * 60000
    }

    Island {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        // The pill floats a little below the screen edge.
        y: 6 * island.pillAmount
        pill: prefs.style.look === "pill"
        palette.accent: prefs.style.accent
        player: source.player
        timer: timerModel
        weather: weatherSource
        calendar: calendarSource
        sound: soundSource
        micApps: prefs.show.privacy ? soundSource.recorders : []
        jobs: jobsModel.summary
        cameraApps: cameraWatcher.apps
        onNotificationClicked: entry => notificationWatcher.openApp(entry)
        onLinkRequested: url => Qt.openUrlExternally(url)
        clipboard: clipboardHistory
        notes: notesStore
        history: history
        newNotifications: history.newCount
        onNotificationsLeft: history.leave()
        links: L.parseLinks(prefs.tools.links)
        colors: L.toList(prefs.tools.colors)
        onColorPickRequested: SystemStatus.pickColor()
        onCopyRequested: text => clipboardHistory.copyText(text)
        extraTool: prefs.panel.extraTool
        onExtraToolChanged: prefs.panel.extraTool = extraTool
        onWantsKeyboardChanged: InputRegion.setKeyboard(root, wantsKeyboard)
        barHeight: prefs.shape.height
        idleWidth: prefs.shape.idleWidth
        compactWidth: prefs.shape.compactWidth
        cornerRadius: prefs.shape.radius
        earSize: prefs.shape.ears
        cycleInterval: prefs.behaviour.cycleSeconds * 1000
        swipeHold: prefs.behaviour.swipeHoldSeconds * 1000
        openOnHover: prefs.behaviour.openOnHover
        quickHidden: L.toList(prefs.quickButtons.hidden)
        panelTime: prefs.panel.time
        panelDate: prefs.panel.date
        battery: SystemStatus.battery
        charging: SystemStatus.charging
        idleMode: prefs.idle.mode
        glances: ({ events: prefs.idle.events, battery: prefs.idle.battery, time: prefs.idle.time, weather: prefs.idle.weather, meetings: prefs.show.meetings })
        idleAnimation: prefs.idle.animation || "builtin:aurora"
        animateOnHoverOnly: prefs.idle.animateOnHoverOnly
        userIdle: SystemStatus.userIdle
        onSettingsRequested: {
            settingsWindow.show()
            settingsWindow.raise()
            settingsWindow.requestActivate()
        }
        onOpenChanged: if (open) {
            SystemStatus.refresh()
            calendarSource.refreshIfStale()
        }
        onInputRectChanged: root.updateInputRegion()
    }

    // Two small file reads; frequent enough to catch a plugged-in charger within a few seconds.
    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: SystemStatus.refreshBattery()
    }

    // Plasma's edit mode puts its toolbar where the island sits. It sends no change signal, so ask once a second.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: SystemStatus.refreshEditMode()
    }

    Connections {
        target: SystemStatus
        function onChanged() {
            if (root.visible === SystemStatus.editMode) {
                island.open = false
                root.visible = !SystemStatus.editMode
                root.updateInputRegion()
            }
        }
        function onAboutToScreenshot() { island.open = false }
        function onColorPicked(hex) {
            prefs.tools.colors = L.pushColor(L.toList(prefs.tools.colors), hex)
            clipboardHistory.copyText(L.colorFormats(hex).hex)
            island.showAlert({ kind: "color", value: hex }, 2500)
        }
        function onBrightnessChanged(percent) { root.showLevel("brightness", percent, false) }
    }

    Component.onCompleted: {
        updateInputRegion()
        PlasmaSettings.setOsdEnabled(!islandLevels)
        PlasmaSettings.setPopupsEnabled(!islandNotifications)
    }
}
