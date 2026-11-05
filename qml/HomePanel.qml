import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

Item {
    id: panel
    objectName: "homePanel"

    property var player: null
    property var playerChoices: []
    signal playerPicked(var p)
    property string artUrl: ""
    // Fill for music progress and volume, and the colour of active music toggles.
    property color musicTint: palette.brightText
    property color accentTint: palette.accent
    // While the pill's cover flies into the panel, the panel's own cover stays hidden.
    property bool coverHidden: false
    property var lyrics: null
    // The cover the pill's cover lands on: the Home card's or the Music tab's, or null.
    function coverTarget() {
        if (tab === "home")
            return findCover(homeTab, "cardCover")
        if (tab === "music")
            return findCover(musicTab, "musicCover")
        return null
    }
    function findCover(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        for (let i = 0; i < item.children.length; ++i) {
            const found = findCover(item.children[i], name)
            if (found)
                return found
        }
        return null
    }
    property var timer: null
    property var weather: null
    property var calendar: null
    property string tab: "home"
    // Esc closes the panel. A focused search box handles its own Esc first.
    signal closeRequested()
    focus: true
    Keys.onEscapePressed: closeRequested()
    // 1-9 and Tab switch tabs; Space plays or pauses; arrows seek. A focused text box keeps its own keys.
    Keys.onPressed: event => {
        const keys = panel.tabKeys
        const at = keys.indexOf(panel.tab)
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            const n = event.key - Qt.Key_1
            if (n < keys.length)
                panel.tab = keys[n]
            event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            const back = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier)
            panel.tab = keys[(Math.max(0, at) + (back ? keys.length - 1 : 1)) % keys.length]
            event.accepted = true
        } else if (event.key === Qt.Key_Space && panel.player) {
            panel.player.PlayPause()
            event.accepted = true
        } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && panel.player && panel.player.canSeek !== false && panel.player.length > 0) {
            const step = (event.key === Qt.Key_Right ? 1 : -1) * 5000000
            panel.player.position = Math.max(0, Math.min(panel.player.length - 1000000, panel.player.position + step))
            event.accepted = true
        }
    }
    // Off in unit tests: the buttons talk to the real system.
    property bool showQuickButtons: true
    property var quickHidden: []
    property bool showTime: true
    property bool showDate: true
    property var sound: null
    property var clipboard: null
    property var notes: null
    // TodoStore for the To-Do tab.
    property var todos: null
    property var updatePackages: []
    property var btDevices: []
    signal upgradeRequested()
    property var shelf: []
    property bool showJoin: true
    property var links: []
    property var colors: []
    // NotificationHistory; its tab is shown only while saving is on.
    property var history: null
    property int newNotifications: 0
    signal notificationClicked(string desktopEntry)
    // Leaving the Notifications tab marks everything in it seen. The panel is destroyed on close, so that counts too.
    signal notificationsLeft()
    property string shownTab
    Component.onCompleted: shownTab = tab
    onTabChanged: {
        if (shownTab === "notifications")
            notificationsLeft()
        shownTab = tab
    }
    Component.onDestruction: {
        if (tab === "notifications")
            notificationsLeft()
        // Closing the panel ends any undo offer; its image file (if any) can go.
        finishUndo()
    }
    signal colorPickRequested()
    signal copyRequested(string text)
    signal linkRequested(string url)
    // The tool picked from the ⋯ menu; it gets the tab slot after the divider.
    property string extraTool: "clipboard"
    readonly property var tools: [
        { key: "clipboard", label: "Clipboard", icon: "edit-paste-symbolic" },
        { key: "notes", label: "Notes", icon: "document-edit-symbolic" },
        { key: "shelf", label: "Shelf", icon: "folder-download-symbolic" },
        { key: "links", label: "Quick links", icon: "link-symbolic" },
        { key: "color", label: "Colour picker", icon: "color-picker-symbolic" }
    ]
    readonly property var extra: tools.find(t => t.key === extraTool) || tools[0]
    property bool menuOpen: false
    readonly property var tabList: [
        { key: "home", label: "Home", icon: "go-home" },
        { key: "music", label: "Music", icon: "media-playback-start" },
        { key: "timer", label: "Timer", icon: "chronometer" },
        { key: "mixer", label: "Sound Mixer", icon: "view-media-equalizer" },
        ...(history && history.settings.save ? [{ key: "notifications", label: "Notifications", icon: "notifications" }] : []),
        { divider: true },
        { key: "todo", label: "To-Do", icon: "view-list-symbolic" },
        { key: extra.key, label: extra.label, icon: extra.icon, name: "extra" },
        { key: "more", label: "More", icon: "overflow-menu" }
    ]
    // The tabs the keyboard steps through, in order (the ⋯ menu isn't one).
    readonly property var tabKeys: tabList.filter(t => !t.divider && t.key !== "more").map(t => t.key)
    readonly property bool wantsKeyboard: tab === "clipboard" || tab === "notes" || tab === "todo"
    // Home is shorter than the other tabs; the island shrinks to it. 0 means use the full height.
    readonly property real fitHeight: tab === "home" ? tabContent.y + homeTab.implicitHeight : 0
    readonly property bool typing: (clipboardTab.item && clipboardTab.item.typing) || (notesTab.item && notesTab.item.typing)
                                   || (todoTab.item && todoTab.item.typing) || false

    // "Deleted · Undo" for a few seconds after removing a note, clipboard item or task.
    // undo() puts it back; expire(), if given, runs once undo is no longer offered.
    property var pendingUndo: null
    function offerUndo(text, undo, expire) {
        finishUndo()
        pendingUndo = { text: text, undo: undo, expire: expire || null }
        undoTimer.restart()
    }
    function finishUndo() {
        const p = pendingUndo
        pendingUndo = null
        undoTimer.stop()
        if (p && p.expire)
            p.expire()
    }
    function runUndo() {
        const p = pendingUndo
        pendingUndo = null
        undoTimer.stop()
        if (p)
            p.undo()
    }
    property int undoMs: 6000
    Timer {
        id: undoTimer
        interval: panel.undoMs
        onTriggered: panel.finishUndo()
    }

    // Puts the keyboard where the current tab wants it: the clipboard's search box.
    function focusTab() {
        if (tab === "clipboard" && clipboardTab.item)
            clipboardTab.item.focusSearch()
    }

    function pickTool(key) {
        extraTool = key
        tab = key
        menuOpen = false
    }
    signal settingsRequested()
    property var now: () => new Date()
    property date clock: now()
    function refreshClock() { clock = now() }

    Timer {
        interval: 10000
        repeat: true
        running: panel.visible
        onTriggered: panel.refreshClock()
    }

    // Centred in the gap between the tabs and the buttons, since the panel may hold no clock.
    Row {
        id: clockRow
        readonly property real gap: (quickSlot.item ? quickSlot.x : settingsButton.x) - tabs.width
        x: (tabs.width + (quickSlot.item ? quickSlot.x : settingsButton.x) - width) / 2
        anchors.verticalCenter: tabs.verticalCenter
        spacing: 8
        Text {
            objectName: "panelTime"
            visible: panel.showTime
            anchors.baseline: parent.children[1].baseline
            text: Qt.formatTime(panel.clock, "HH:mm")
            color: palette.windowText
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        Text {
            objectName: "panelDate"
            // Dropped when a wide open tab leaves no room beside the time.
            visible: panel.showDate && clockRow.gap >= (panel.showTime ? parent.children[0].implicitWidth + 8 : 0) + implicitWidth + 24
            text: Qt.formatDate(panel.clock, "ddd d MMM")
            color: palette.placeholderText
            font.pixelSize: 13
        }
    }

    Rectangle {
        id: tabs
        width: tabsRow.implicitWidth + 8
        height: tabsRow.implicitHeight + 8
        radius: height / 2
        color: palette.base

        Row {
            id: tabsRow
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: panel.tabList
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool selected: panel.tab === modelData.key
                    // One animated value drives the name, spacing, padding and background together,
                    // so the pill never lags behind the name sliding out.
                    property real grow: selected ? 1 : 0
                    Behavior on grow { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    readonly property bool lit: modelData.key === "more" && panel.menuOpen
                    objectName: modelData.divider ? "" : "tab-" + (modelData.name || modelData.key)
                    // Icons only; the open tab slides out to show its name.
                    width: modelData.divider ? 1 : tabRow.width + 18 + 8 * grow
                    height: modelData.divider ? 16 : 30
                    anchors.verticalCenter: parent.verticalCenter
                    radius: modelData.divider ? 0 : 15
                    color: modelData.divider ? palette.button
                         : lit ? palette.button
                         : tabArea.containsMouse && !selected ? palette.alternateBase
                         : Qt.rgba(palette.button.r, palette.button.g, palette.button.b, grow)

                    Row {
                        id: tabRow
                        visible: !modelData.divider
                        anchors.centerIn: parent
                        spacing: 7 * grow
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 15
                            height: 15
                            source: modelData.icon || ""
                            color: selected || tabArea.containsMouse || (modelData.key === "more" && panel.menuOpen) ? palette.windowText : palette.placeholderText
                            isMask: true
                        }
                        Text {
                            objectName: "tabLabel-" + (modelData.name || modelData.key)
                            anchors.verticalCenter: parent.verticalCenter
                            width: implicitWidth * grow
                            clip: true
                            opacity: grow
                            text: modelData.label || ""
                            color: palette.windowText
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            objectName: modelData.key === "notifications" ? "notificationsBadge" : ""
                            visible: modelData.key === "notifications" && panel.newNotifications > 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(16, badgeText.implicitWidth + 10)
                            height: 16
                            radius: 8
                            color: "#ffb340"
                            Text {
                                id: badgeText
                                objectName: modelData.key === "notifications" ? "notificationsBadgeText" : ""
                                anchors.centerIn: parent
                                text: panel.newNotifications
                                color: "#1a1205"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        enabled: !modelData.divider
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.key === "more") {
                                panel.menuOpen = !panel.menuOpen
                            } else {
                                panel.tab = modelData.key
                                panel.menuOpen = false
                            }
                        }
                    }
                    QQC.ToolTip.visible: tabArea.containsMouse && !selected && !modelData.divider && !(modelData.key === "more" && panel.menuOpen)
                    QQC.ToolTip.text: modelData.label || ""
                    QQC.ToolTip.delay: 400
                }
            }
        }
    }

    Loader {
        id: quickSlot
        objectName: "quickSlot"
        anchors.right: settingsButton.left
        anchors.rightMargin: 6
        anchors.verticalCenter: tabs.verticalCenter
        active: panel.showQuickButtons
        source: "QuickButtons.qml"
    }
    Binding {
        target: quickSlot.item
        property: "hidden"
        value: panel.quickHidden
        when: quickSlot.item !== null
    }
    Binding {
        target: quickSlot.item
        property: "devices"
        value: panel.btDevices
        when: quickSlot.item !== null
    }

    Rectangle {
        id: settingsButton
        objectName: "settingsButton"
        anchors.right: parent.right
        anchors.verticalCenter: tabs.verticalCenter
        width: 30
        height: 30
        radius: 15
        color: settingsArea.containsMouse ? palette.button : palette.base
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 15
            height: 15
            source: "configure"
            color: palette.windowText
            isMask: true
        }
        MouseArea {
            id: settingsArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: panel.settingsRequested()
        }
    }

    Item {
        id: tabContent
        objectName: "tabContent"
        anchors.top: tabs.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Row {
            id: homeTab
            objectName: "homeTab"
            anchors.fill: parent
            visible: panel.tab === "home"
            spacing: 26

            Column {
                width: 300
                spacing: 16
                MusicCard {
                    width: parent.width
                    player: panel.player
                    artUrl: panel.artUrl
                    tint: panel.musicTint
                    coverHidden: panel.coverHidden
                }
                MonthCalendar {
                    id: monthCalendar
                    width: parent.width
                    calendar: panel.calendar
                    onDayPicked: day => upNext.day = day
                }
            }

            Column {
                width: parent.width - 300 - 200 - 2 * parent.spacing
                spacing: 22
                WeatherCard {
                    objectName: "weatherCard"
                    width: parent.width
                    weather: panel.weather
                    onForecastRequested: url => panel.linkRequested(url)
                }
                UpNext {
                    id: upNext
                    objectName: "upNext"
                    width: parent.width
                    calendar: panel.calendar
                    onDayCleared: {
                        day = null
                        monthCalendar.selected = null
                    }
                    showJoin: panel.showJoin
                    onLinkRequested: url => panel.linkRequested(url)
                }
            }

            Loader {
                width: 200
                active: panel.timer !== null
                sourceComponent: TimerCard {
                    width: 200
                    timer: panel.timer
                }
            }
        }
        MusicPlayer {
            id: musicTab
            objectName: "musicPlayer"
            choices: panel.playerChoices
            onPicked: p => panel.playerPicked(p)
            coverHidden: panel.coverHidden
            lyrics: panel.lyrics
            anchors.fill: parent
            visible: panel.tab === "music"
            player: panel.player
            artUrl: panel.artUrl
            tint: panel.musicTint
            accentTint: panel.accentTint
        }
        Loader {
            objectName: "mixerTab"
            anchors.fill: parent
            active: panel.tab === "mixer" && panel.sound !== null
            sourceComponent: Mixer {
                Component.onCompleted: panel.sound.monitorMic = true
                Component.onDestruction: panel.sound.monitorMic = false
                outputs: panel.sound.outputs
                inputs: panel.sound.inputs
                apps: panel.sound.apps
                micLevel: panel.sound.micLevel
            }
        }
        Loader {
            id: clipboardTab
            objectName: "clipboardTab"
            anchors.fill: parent
            active: panel.tab === "clipboard" && panel.clipboard !== null
            sourceComponent: ClipboardTab {
                items: panel.clipboard.items
                onCopyRequested: id => panel.clipboard.copy(id)
                onPinRequested: (id, on) => panel.clipboard.pin(id, on)
                onRemoveRequested: id => {
                    const taken = panel.clipboard.take(id)
                    if (taken.item)
                        panel.offerUndo("Clipboard item deleted", () => panel.clipboard.restore(taken), () => panel.clipboard.discard(taken))
                }
                onClearRequested: panel.clipboard.clear()
            }
        }
        Loader {
            objectName: "shelfTab"
            anchors.fill: parent
            active: panel.tab === "shelf"
            sourceComponent: ShelfTab {
                files: panel.shelf
                onEdited: list => panel.shelf = list
            }
        }
        Loader {
            objectName: "linksTab"
            anchors.fill: parent
            active: panel.tab === "links"
            sourceComponent: QuickLinksTab {
                links: panel.links
                onOpenRequested: url => panel.linkRequested(url)
                onSettingsRequested: panel.settingsRequested()
            }
        }
        Loader {
            objectName: "colorTab"
            anchors.fill: parent
            active: panel.tab === "color"
            sourceComponent: ColorTab {
                colors: panel.colors
                onPickRequested: panel.colorPickRequested()
                onCopyRequested: text => panel.copyRequested(text)
            }
        }
        Loader {
            id: notesTab
            objectName: "notesTab"
            anchors.fill: parent
            active: panel.tab === "notes" && panel.notes !== null
            sourceComponent: NotesTab {
                notes: panel.notes.notes
                readNote: id => panel.notes.read(id)
                writeNote: (id, text) => panel.notes.write(id, text)
                newId: () => panel.notes.newId()
                onDeleteRequested: (id, text) => {
                    panel.notes.write(id, "")
                    panel.offerUndo("Note deleted", () => {
                        panel.notes.write(id, text)
                        if (notesTab.item)
                            notesTab.item.open(id)
                    })
                }
            }
        }
        Loader {
            objectName: "notificationsTab"
            anchors.fill: parent
            active: panel.tab === "notifications" && panel.history !== null
            sourceComponent: NotificationsTab {
                groups: panel.history.groups
                lastSeen: panel.history.lastSeen
                onOpenRequested: (id, entry) => {
                    panel.history.markSeen(id)
                    if (entry)
                        panel.notificationClicked(entry)
                }
                onRemoveRequested: id => panel.history.remove(id)
                onClearRequested: panel.history.clear()
            }
        }
        Loader {
            objectName: "timerTab"
            anchors.fill: parent
            active: panel.tab === "timer" && panel.timer !== null
            sourceComponent: TimerTab {
                timer: panel.timer
            }
        }
        Loader {
            objectName: "updatesTab"
            anchors.fill: parent
            active: panel.tab === "updates"
            sourceComponent: UpdatesTab {
                packages: panel.updatePackages
                onUpgradeRequested: panel.upgradeRequested()
            }
        }
        Loader {
            id: todoTab
            objectName: "todoTab"
            anchors.fill: parent
            active: panel.tab === "todo" && panel.todos !== null
            sourceComponent: TodoList {
                items: panel.todos.items
                addItem: text => panel.todos.add(text)
                setDone: (id, done) => panel.todos.setDone(id, done)
                removeItem: id => {
                    const removed = panel.todos.remove(id)
                    if (removed.item)
                        panel.offerUndo("Task deleted", () => panel.todos.restore(removed))
                }
                clearDone: () => panel.todos.clearDone()
            }
        }
    }

    Rectangle {
        objectName: "undoBar"
        visible: opacity > 0
        opacity: panel.pendingUndo ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        z: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        width: undoRow.implicitWidth + 28
        height: 34
        radius: 17
        color: palette.button
        border.color: palette.dark
        Row {
            id: undoRow
            anchors.centerIn: parent
            spacing: 14
            Text {
                objectName: "undoText"
                anchors.verticalCenter: parent.verticalCenter
                text: panel.pendingUndo ? panel.pendingUndo.text : ""
                color: palette.windowText
                font.pixelSize: 12
            }
            Text {
                objectName: "undoButton"
                anchors.verticalCenter: parent.verticalCenter
                text: "Undo"
                color: undoArea.containsMouse ? Qt.lighter(palette.accent, 1.2) : palette.accent
                font.pixelSize: 12
                font.weight: Font.DemiBold
                MouseArea {
                    id: undoArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.runUndo()
                }
            }
        }
    }

    // Clicking anywhere else closes the menu.
    MouseArea {
        anchors.fill: parent
        visible: panel.menuOpen
        z: 9
        onClicked: panel.menuOpen = false
    }

    Rectangle {
        id: moreMenu
        objectName: "moreMenu"
        visible: panel.menuOpen
        z: 10
        x: tabs.width - width
        y: tabs.height + 6
        width: 150
        height: menuColumn.height + 12
        radius: 16
        color: palette.base
        border.color: palette.button

        Column {
            id: menuColumn
            x: 6
            y: 6
            width: parent.width - 12
            Repeater {
                model: panel.tools
                delegate: Rectangle {
                    required property var modelData
                    objectName: "menu-" + modelData.key
                    width: menuColumn.width
                    height: 36
                    radius: 10
                    color: itemArea.containsMouse ? palette.button : "transparent"
                    Row {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 7
                            color: panel.extraTool === modelData.key ? palette.accent : palette.button
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                source: modelData.icon
                                color: panel.extraTool === modelData.key ? "#ffffff" : palette.windowText
                                isMask: true
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: palette.windowText
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: panel.pickTool(modelData.key)
                    }
                }
            }
        }
    }
}
