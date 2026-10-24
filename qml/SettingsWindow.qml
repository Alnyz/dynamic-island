import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import org.kde.kirigami as Kirigami
import Island
import "logic.js" as L

QQC.ApplicationWindow {
    id: win

    required property var prefs
    property var calendar: null

    title: "Dynamic Island settings"
    width: 760
    height: 600
    minimumWidth: 620
    minimumHeight: 400
    // The island is a layer-shell surface, which can't parent a normal window.
    transientParent: null

    readonly property var calendarUrls: L.toList(prefs.calendar.icsUrls)
    readonly property var disabledUrls: L.toList(prefs.calendar.disabled)
    readonly property var hiddenButtons: L.toList(prefs.quickButtons.hidden)
    readonly property var links: L.parseLinks(prefs.tools.links)

    function saveLinks(list) { prefs.tools.links = JSON.stringify(list) }
    function moved(list, from, to) {
        const out = list.slice()
        out.splice(to, 0, out.splice(from, 1)[0])
        return out
    }

    function toggled(list, item, on) {
        const rest = list.filter(x => x !== item)
        return on ? rest.concat([item]) : rest
    }

    property int page: 0
    readonly property var pages: [
            { label: "Look", icon: "preferences-desktop-theme-global" },
            { label: "Behaviour", icon: "preferences-system-windows-behavior" },
            { label: "Alerts", icon: "preferences-desktop-notification" },
            { label: "When idle", icon: "preferences-desktop-screensaver" },
            { label: "Calendar", icon: "view-calendar" },
            { label: "Weather", icon: "weather-few-clouds" },
            { label: "Quick buttons", icon: "view-grid" },
            { label: "Quick links", icon: "link" },
            { label: "General", icon: "preferences-system" }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // One page per topic, so no single page turns into a long scroll.
        QQC.ScrollView {
            Layout.fillHeight: true
            Layout.preferredWidth: 190
            ListView {
                topMargin: Kirigami.Units.smallSpacing
                model: win.pages
                delegate: QQC.ItemDelegate {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    text: modelData.label
                    icon.name: modelData.icon
                    highlighted: win.page === index
                    onClicked: win.page = index
                }
            }
        }
        Kirigami.Separator { Layout.fillHeight: true }
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: win.page
            Page {
                title: "Look"
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    QQC.ButtonGroup { id: lookGroup }
                    QQC.RadioButton {
                        Kirigami.FormData.label: "Style:"
                        text: "Notch, joined to the top edge"
                        QQC.ButtonGroup.group: lookGroup
                        checked: win.prefs.style.look === "notch"
                        onToggled: win.prefs.style.look = "notch"
                    }
                    QQC.RadioButton {
                        text: "Pill, floating below the edge"
                        QQC.ButtonGroup.group: lookGroup
                        checked: win.prefs.style.look === "pill"
                        onToggled: win.prefs.style.look = "pill"
                    }
                    RowLayout {
                        Kirigami.FormData.label: "Accent colour:"
                        spacing: 8
                        Repeater {
                            model: ["#0a84ff", "#5e5ce6", "#bf5af2", "#ff375f", "#ff453a", "#ff9f0a", "#ffd60a", "#30d158", "#64d2ff", "#8e8e93"]
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool current: win.prefs.style.accent.toLowerCase() === modelData
                                width: 26
                                height: 26
                                radius: 13
                                color: modelData
                                border.width: current ? 3 : 0
                                border.color: Kirigami.Theme.textColor
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.prefs.style.accent = parent.modelData
                                }
                            }
                        }
                        QQC.Button {
                            text: "Custom…"
                            icon.name: "color-picker"
                            onClicked: accentDialog.open()
                        }
                    }
                    ColorDialog {
                        id: accentDialog
                        title: "Choose an accent colour"
                        selectedColor: win.prefs.style.accent
                        onAccepted: win.prefs.style.accent = selectedColor.toString()
                    }
                    Item { Kirigami.FormData.isSection: true }
                    SliderRow {
                        Kirigami.FormData.label: "Height:"
                        from: 24; to: 48; suffix: " px"
                        value: win.prefs.shape.height
                        onMoved: v => win.prefs.shape.height = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: "Width when empty:"
                        from: 100; to: 320; suffix: " px"
                        value: win.prefs.shape.idleWidth
                        onMoved: v => win.prefs.shape.idleWidth = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: "Width with music or timer:"
                        from: 160; to: 420; suffix: " px"
                        value: win.prefs.shape.compactWidth
                        onMoved: v => win.prefs.shape.compactWidth = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: "Corner roundness:"
                        from: 0; to: 20; suffix: " px"
                        value: win.prefs.shape.radius
                        onMoved: v => win.prefs.shape.radius = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: "Curves at the top:"
                        enabled: win.prefs.style.look === "notch"
                        from: 0; to: 16; suffix: " px"
                        value: win.prefs.shape.ears
                        onMoved: v => win.prefs.shape.ears = v
                    }
                }
            }
            Page {
                title: "Behaviour"
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    SliderRow {
                        Kirigami.FormData.label: "Switch music and timer every:"
                        from: 3; to: 30; suffix: " s"
                        value: win.prefs.behaviour.cycleSeconds
                        onMoved: v => win.prefs.behaviour.cycleSeconds = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: "After a swipe, hold for:"
                        from: 5; to: 60; suffix: " s"
                        value: win.prefs.behaviour.swipeHoldSeconds
                        onMoved: v => win.prefs.behaviour.swipeHoldSeconds = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: "Keep paused music for:"
                        from: 1; to: 60; suffix: " min"
                        value: win.prefs.behaviour.pausedMinutes
                        onMoved: v => win.prefs.behaviour.pausedMinutes = v
                    }
                    QQC.ButtonGroup { id: openGroup }
                    QQC.RadioButton {
                        Kirigami.FormData.label: "Open the panel:"
                        text: "On click"
                        QQC.ButtonGroup.group: openGroup
                        checked: !win.prefs.behaviour.openOnHover
                        onToggled: win.prefs.behaviour.openOnHover = false
                    }
                    QQC.RadioButton {
                        text: "When the pointer rests on it"
                        QQC.ButtonGroup.group: openGroup
                        checked: win.prefs.behaviour.openOnHover
                        onToggled: win.prefs.behaviour.openOnHover = true
                    }
                }
            }
            Page {
                title: "Alerts"
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: [
                            { key: "levels", label: "Volume and brightness (hides Plasma's box)" },
                            { key: "notifications", label: "Notifications (hides Plasma's popups)" },
                            { key: "privacy", label: "Microphone and camera in use" },
                            { key: "devices", label: "Bluetooth devices connecting" },
                            { key: "meetings", label: "Join button for meetings" },
                            { key: "power", label: "Charger plugged in or out" }
                        ]
                        delegate: QQC.CheckBox {
                            required property var modelData
                            required property int index
                            Kirigami.FormData.label: index === 0 ? "Show:" : ""
                            text: modelData.label
                            checked: win.prefs.show[modelData.key]
                            onToggled: win.prefs.show[modelData.key] = checked
                        }
                    }
                }
            }
            Page {
                title: "When idle"
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    QQC.ButtonGroup { id: idleGroup }
                    Repeater {
                        model: [
                            { key: "glances", label: "Glances" },
                            { key: "animation", label: "My animation" },
                            { key: "nothing", label: "Nothing" }
                        ]
                        delegate: QQC.RadioButton {
                            required property var modelData
                            required property int index
                            Kirigami.FormData.label: index === 0 ? "Show:" : ""
                            text: modelData.label
                            QQC.ButtonGroup.group: idleGroup
                            checked: win.prefs.idle.mode === modelData.key
                            onToggled: win.prefs.idle.mode = modelData.key
                        }
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "glances"
                        Kirigami.FormData.label: "Glances:"
                        text: "Events starting soon"
                        checked: win.prefs.idle.events
                        onToggled: win.prefs.idle.events = checked
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "glances"
                        text: "Battery low or charging"
                        checked: win.prefs.idle.battery
                        onToggled: win.prefs.idle.battery = checked
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "glances"
                        text: "Time"
                        checked: win.prefs.idle.time
                        onToggled: win.prefs.idle.time = checked
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "glances"
                        text: "Weather"
                        checked: win.prefs.idle.weather
                        onToggled: win.prefs.idle.weather = checked
                    }
                    QQC.ComboBox {
                        id: artPicker
                        visible: win.prefs.idle.mode === "animation"
                        Kirigami.FormData.label: "Animation:"
                        readonly property string current: win.prefs.idle.animation || "builtin:aurora"
                        textRole: "label"
                        valueRole: "key"
                        model: [
                            { key: "builtin:aurora", label: "Aurora" },
                            { key: "builtin:wave", label: "Wave" },
                            { key: "builtin:fireflies", label: "Fireflies" },
                            { key: "builtin:cat", label: "Cat" },
                            { key: "file", label: "My own GIF or WebP…" }
                        ]
                        currentIndex: current.startsWith("builtin:") ? Math.max(0, indexOfValue(current)) : 4
                        onActivated: {
                            if (currentValue === "file")
                                animationDialog.open()
                            else
                                win.prefs.idle.animation = currentValue
                        }
                    }
                    RowLayout {
                        visible: win.prefs.idle.mode === "animation" && !artPicker.current.startsWith("builtin:")
                        Kirigami.FormData.label: "File:"
                        QQC.Label {
                            Layout.maximumWidth: 200
                            elide: Text.ElideMiddle
                            text: decodeURIComponent(artPicker.current.split("/").pop())
                        }
                        QQC.Button {
                            text: "Change…"
                            icon.name: "document-open"
                            onClicked: animationDialog.open()
                        }
                    }
                    QQC.Label {
                        visible: win.prefs.idle.mode === "animation"
                        text: "Point at the island to see it play."
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "animation"
                        text: "Only play when the pointer is on the island"
                        checked: win.prefs.idle.animateOnHoverOnly
                        onToggled: win.prefs.idle.animateOnHoverOnly = checked
                    }
                    FileDialog {
                        id: animationDialog
                        title: "Choose an animation"
                        nameFilters: ["Animations (*.gif *.webp)"]
                        onAccepted: win.prefs.idle.animation = selectedFile.toString()
                        onRejected: artPicker.currentIndex = artPicker.current.startsWith("builtin:") ? artPicker.indexOfValue(artPicker.current) : 4
                    }
                }
            }
            Page {
                title: "Calendar"
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    SliderRow {
                        Kirigami.FormData.label: "Check for changes every:"
                        from: 5; to: 120; suffix: " min"
                        value: win.prefs.calendar.refreshMinutes
                        onMoved: v => win.prefs.calendar.refreshMinutes = v
                    }
                    // One child for the whole list: rows added later would otherwise land at the end of the form.
                    ColumnLayout {
                        Kirigami.FormData.label: "Calendars:"
                        Kirigami.FormData.labelAlignment: Qt.AlignTop
                        QQC.Label {
                            visible: win.calendarUrls.length === 0
                            text: "None yet"
                            opacity: 0.7
                        }
                        Repeater {
                            model: win.calendarUrls
                            delegate: RowLayout {
                                required property string modelData
                                QQC.Switch {
                                    text: L.calendarLabel(modelData)
                                    checked: !win.disabledUrls.includes(modelData)
                                    onToggled: win.prefs.calendar.disabled = win.toggled(win.disabledUrls, modelData, !checked)
                                }
                                QQC.ToolButton {
                                    icon.name: "edit-delete-remove"
                                    text: "Remove"
                                    display: QQC.AbstractButton.IconOnly
                                    QQC.ToolTip.text: text
                                    QQC.ToolTip.visible: hovered
                                    onClicked: {
                                        win.prefs.calendar.icsUrls = win.calendarUrls.filter(u => u !== modelData)
                                        win.prefs.calendar.disabled = win.disabledUrls.filter(u => u !== modelData)
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Kirigami.FormData.label: "Add a calendar:"
                        QQC.TextField {
                            id: newUrl
                            Layout.preferredWidth: 240
                            // It's a secret link, so keep it off the screen.
                            echoMode: TextInput.Password
                            placeholderText: "Secret address in iCal format"
                            onAccepted: addButton.clicked()
                        }
                        QQC.Button {
                            id: addButton
                            text: "Add"
                            enabled: /^https?:\/\//.test(newUrl.text.trim()) && !win.calendarUrls.includes(newUrl.text.trim())
                            onClicked: {
                                win.prefs.calendar.icsUrls = win.calendarUrls.concat([newUrl.text.trim()])
                                newUrl.clear()
                            }
                        }
                    }
                    QQC.Label {
                        text: "Google Calendar → Settings → your calendar → Integrate calendar → Secret address in iCal format."
                        wrapMode: Text.Wrap
                        Layout.maximumWidth: 300
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                    }
                    RowLayout {
                        visible: win.calendar !== null && win.calendarUrls.length > 0
                        QQC.Button {
                            text: "Refresh now"
                            icon.name: "view-refresh"
                            onClicked: win.calendar.refresh()
                        }
                        QQC.Label {
                            opacity: 0.7
                            text: !win.calendar || !win.calendar.loaded ? ""
                                : win.calendar.ok ? "Updated " + Qt.formatTime(win.calendar.lastSuccess, "HH:mm")
                                : "Couldn't reach the calendar"
                        }
                    }
                }
            }
            Page {
                title: "Weather"
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    QQC.ButtonGroup { id: placeGroup }
                    QQC.RadioButton {
                        id: autoPlace
                        Kirigami.FormData.label: "Location:"
                        text: "Find automatically"
                        QQC.ButtonGroup.group: placeGroup
                        checked: win.prefs.weather.city === ""
                        onToggled: win.prefs.weather.city = ""
                    }
                    QQC.RadioButton {
                        id: manualPlace
                        text: win.prefs.weather.city !== "" ? "Use " + win.prefs.weather.city : "Use a city I choose"
                        QQC.ButtonGroup.group: placeGroup
                        checked: win.prefs.weather.city !== ""
                    }
                    RowLayout {
                        visible: manualPlace.checked
                        QQC.TextField {
                            id: cityField
                            Layout.preferredWidth: 200
                            placeholderText: "City name"
                            onAccepted: findButton.clicked()
                        }
                        QQC.Button {
                            id: findButton
                            text: "Find"
                            enabled: cityField.text.trim() !== ""
                            onClicked: win.findCity(cityField.text.trim())
                        }
                    }
                    QQC.Label {
                        id: cityStatus
                        visible: manualPlace.checked && text !== ""
                        opacity: 0.7
                    }
                    QQC.ButtonGroup { id: unitGroup }
                    QQC.RadioButton {
                        Kirigami.FormData.label: "Temperature:"
                        text: "°C"
                        QQC.ButtonGroup.group: unitGroup
                        checked: !win.prefs.weather.fahrenheit
                        onToggled: win.prefs.weather.fahrenheit = false
                    }
                    QQC.RadioButton {
                        text: "°F"
                        QQC.ButtonGroup.group: unitGroup
                        checked: win.prefs.weather.fahrenheit
                        onToggled: win.prefs.weather.fahrenheit = true
                    }
                }
            }
            Page {
                title: "Quick buttons"
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: [
                            { key: "battery", label: "Battery" },
                            { key: "volume", label: "Volume" },
                            { key: "wifi", label: "Wi-Fi" },
                            { key: "bluetooth", label: "Bluetooth" },
                            { key: "dnd", label: "Do not disturb" },
                            { key: "awake", label: "Keep screen awake" },
                            { key: "screenshot", label: "Screenshot" },
                            { key: "lock", label: "Lock screen" }
                        ]
                        delegate: QQC.CheckBox {
                            required property var modelData
                            required property int index
                            Kirigami.FormData.label: index === 0 ? "Show:" : ""
                            text: modelData.label
                            checked: !win.hiddenButtons.includes(modelData.key)
                            onToggled: win.prefs.quickButtons.hidden = win.toggled(win.hiddenButtons, modelData.key, !checked)
                        }
                    }
                }
            }
            Page {
                title: "Quick links"
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    // One child for the whole list: rows added later would otherwise land at the end of the form.
                    ColumnLayout {
                        Kirigami.FormData.label: "Links:"
                        Kirigami.FormData.labelAlignment: Qt.AlignTop
                        QQC.Label {
                            visible: win.links.length === 0
                            text: "None yet"
                            opacity: 0.7
                        }
                        Repeater {
                            model: win.links
                            delegate: RowLayout {
                                required property var modelData
                                required property int index
                                QQC.Label {
                                    Layout.preferredWidth: 220
                                    elide: Text.ElideRight
                                    text: (modelData.name || L.linkName(modelData.url)) + "  ·  " + L.linkName(modelData.url)
                                }
                                QQC.ToolButton {
                                    icon.name: "go-up"
                                    text: "Move up"
                                    display: QQC.AbstractButton.IconOnly
                                    enabled: index > 0
                                    QQC.ToolTip.text: text
                                    QQC.ToolTip.visible: hovered
                                    onClicked: win.saveLinks(win.moved(win.links, index, index - 1))
                                }
                                QQC.ToolButton {
                                    icon.name: "edit-delete-remove"
                                    text: "Remove"
                                    display: QQC.AbstractButton.IconOnly
                                    QQC.ToolTip.text: text
                                    QQC.ToolTip.visible: hovered
                                    onClicked: win.saveLinks(win.links.filter((_, i) => i !== index))
                                }
                            }
                        }
                    }
                    QQC.TextField {
                        id: linkAddress
                        Kirigami.FormData.label: "Add a link:"
                        Layout.preferredWidth: 280
                        placeholderText: "Site or folder, e.g. ~/Documents"
                        onAccepted: addLink.clicked()
                    }
                    RowLayout {
                        QQC.TextField {
                            id: linkName
                            Layout.preferredWidth: 200
                            placeholderText: "Name (optional)"
                            onAccepted: addLink.clicked()
                        }
                        QQC.Button {
                            id: addLink
                            text: "Add"
                            icon.name: "list-add"
                            enabled: linkAddress.text.trim() !== ""
                            onClicked: {
                                const url = L.linkUrl(linkAddress.text, StandardPaths.writableLocation(StandardPaths.HomeLocation).toString())
                                win.saveLinks(win.links.concat([{ name: linkName.text.trim(), url: url }]))
                                linkAddress.clear()
                                linkName.clear()
                            }
                        }
                    }
                    QQC.Label {
                        text: "They open from the island: ⋯ → Quick links."
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
            Page {
                title: "General"
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    QQC.Switch {
                        Kirigami.FormData.label: "Start at login:"
                        checked: AppConfig.autostart
                        onToggled: AppConfig.autostart = checked
                    }
                    QQC.Button {
                        text: "Reset to defaults"
                        icon.name: "edit-reset"
                        onClicked: win.prefs.reset()
                    }
                    QQC.Label {
                        text: "Your calendars and animation file are kept."
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }
    }

    function findCity(name) {
        cityStatus.text = "Looking…"
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            let hit = null
            try {
                const results = JSON.parse(xhr.responseText).results
                hit = results && results.length ? results[0] : null
            } catch (e) {}
            if (xhr.status !== 200 || !hit) {
                cityStatus.text = xhr.status === 200 ? "No city found with that name" : "Couldn't search right now"
                return
            }
            win.prefs.weather.latitude = hit.latitude
            win.prefs.weather.longitude = hit.longitude
            win.prefs.weather.city = hit.name
            cityStatus.text = "Using " + hit.name + (hit.country ? ", " + hit.country : "")
            cityField.clear()
        }
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(name))
        xhr.send()
    }

    component Page: QQC.ScrollView {
        id: pageView
        property string title
        default property alias content: column.data
        contentWidth: availableWidth
        ColumnLayout {
            id: column
            width: pageView.availableWidth
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Heading {
                Layout.topMargin: Kirigami.Units.largeSpacing * 2
                Layout.leftMargin: Kirigami.Units.largeSpacing * 3
                text: pageView.title
                level: 2
            }
        }
    }

    component SliderRow: RowLayout {
        id: row
        property int from
        property int to
        property int value
        property string suffix
        signal moved(int v)
        QQC.Slider {
            Layout.preferredWidth: 200
            from: row.from
            to: row.to
            stepSize: 1
            value: row.value
            onMoved: row.moved(Math.round(value))
        }
        QQC.Label {
            text: row.value + row.suffix
            Layout.minimumWidth: 60
        }
    }
}
