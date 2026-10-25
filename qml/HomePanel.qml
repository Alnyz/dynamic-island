import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

Item {
    id: panel
    objectName: "homePanel"

    property var player: null
    property var timer: null
    property var weather: null
    property var calendar: null
    property string tab: "home"
    // Off in unit tests: the buttons talk to the real system.
    property bool showQuickButtons: true
    property var quickHidden: []
    property bool showTime: true
    property bool showDate: true
    property var sound: null
    property var clipboard: null
    property var notes: null
    property var shelf: []
    property bool showJoin: true
    property var links: []
    property var colors: []
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
    readonly property bool wantsKeyboard: tab === "clipboard" || tab === "notes"
    readonly property bool typing: (clipboardTab.item && clipboardTab.item.typing) || (notesTab.item && notesTab.item.typing) || false

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
            color: "#ffffff"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        Text {
            objectName: "panelDate"
            // Dropped when a wide open tab leaves no room beside the time.
            visible: panel.showDate && clockRow.gap >= (panel.showTime ? parent.children[0].implicitWidth + 8 : 0) + implicitWidth + 24
            text: Qt.formatDate(panel.clock, "ddd d MMM")
            color: "#9aa3ad"
            font.pixelSize: 13
        }
    }

    Rectangle {
        id: tabs
        width: tabsRow.implicitWidth + 8
        height: tabsRow.implicitHeight + 8
        radius: height / 2
        color: "#141414"

        Row {
            id: tabsRow
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: [
                    { key: "home", label: "Home", icon: "go-home" },
                    { key: "music", label: "Music", icon: "media-playback-start" },
                    { key: "timer", label: "Timer", icon: "chronometer" },
                    { key: "mixer", label: "Sound Mixer", icon: "view-media-equalizer" },
                    { divider: true },
                    { key: panel.extra.key, label: panel.extra.label, icon: panel.extra.icon, name: "extra" },
                    { key: "more", label: "More", icon: "overflow-menu" }
                ]
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
                    color: modelData.divider ? "#2a2a2a"
                         : lit ? "#2a2a2a"
                         : tabArea.containsMouse && !selected ? "#1c1c1c"
                         : Qt.rgba(0x2a / 255, 0x2a / 255, 0x2a / 255, grow)

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
                            color: selected || tabArea.containsMouse || (modelData.key === "more" && panel.menuOpen) ? "#ffffff" : "#9aa3ad"
                            isMask: true
                        }
                        Text {
                            objectName: "tabLabel-" + (modelData.name || modelData.key)
                            anchors.verticalCenter: parent.verticalCenter
                            width: implicitWidth * grow
                            clip: true
                            opacity: grow
                            text: modelData.label || ""
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
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

    Rectangle {
        id: settingsButton
        objectName: "settingsButton"
        anchors.right: parent.right
        anchors.verticalCenter: tabs.verticalCenter
        width: 30
        height: 30
        radius: 15
        color: settingsArea.containsMouse ? "#2a2a2a" : "#141414"
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 15
            height: 15
            source: "configure"
            color: "#ffffff"
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
        objectName: "tabContent"
        anchors.top: tabs.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Row {
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
                }
                MonthCalendar {
                    width: parent.width
                    calendar: panel.calendar
                }
            }

            Column {
                width: parent.width - 300 - 200 - 2 * parent.spacing
                spacing: 22
                WeatherCard {
                    width: parent.width
                    weather: panel.weather
                }
                UpNext {
                    width: parent.width
                    calendar: panel.calendar
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
            anchors.fill: parent
            visible: panel.tab === "music"
            player: panel.player
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
                onRemoveRequested: id => panel.clipboard.remove(id)
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
        color: "#161616"
        border.color: "#262626"

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
                    color: itemArea.containsMouse ? "#222222" : "transparent"
                    Row {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 7
                            color: panel.extraTool === modelData.key ? palette.accent : "#232323"
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                source: modelData.icon
                                color: "#ffffff"
                                isMask: true
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: "#ffffff"
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
