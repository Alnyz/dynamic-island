import QtQuick
import QtCore

QtObject {
    id: prefs

    // file: URL of the config file.
    required property string location

    readonly property var defaults: ({
        style: { look: "notch", accent: "#0a84ff" },
        shape: { height: 32, idleWidth: 180, compactWidth: 260, radius: 12, ears: 8 },
        behaviour: { cycleSeconds: 6, swipeHoldSeconds: 15, pausedMinutes: 5, openOnHover: false },
        weather: { city: "", latitude: 0, longitude: 0, fahrenheit: false },
        quickButtons: { hidden: [] },
        show: { levels: true, notifications: true, privacy: true, devices: true, meetings: true, power: true },
        idle: { mode: "glances", events: true, battery: true, time: true, weather: true, animateOnHoverOnly: true }
    })

    // look: "notch" (joined to the top edge) or "pill" (floating below it).
    property Settings style: Settings {
        location: prefs.location
        category: "style"
        property string look: prefs.defaults.style.look
        property string accent: prefs.defaults.style.accent
    }

    property Settings shape: Settings {
        location: prefs.location
        category: "shape"
        property int height: prefs.defaults.shape.height
        property int idleWidth: prefs.defaults.shape.idleWidth
        property int compactWidth: prefs.defaults.shape.compactWidth
        property int radius: prefs.defaults.shape.radius
        property int ears: prefs.defaults.shape.ears
    }

    property Settings behaviour: Settings {
        location: prefs.location
        category: "behaviour"
        property int cycleSeconds: prefs.defaults.behaviour.cycleSeconds
        property int swipeHoldSeconds: prefs.defaults.behaviour.swipeHoldSeconds
        property int pausedMinutes: prefs.defaults.behaviour.pausedMinutes
        property bool openOnHover: prefs.defaults.behaviour.openOnHover
    }

    // Calendar links are not part of reset: they are the user's data, not a look.
    property Settings calendar: Settings {
        location: prefs.location
        category: "calendar"
        property var icsUrls: []
        property var disabled: []
        property int refreshMinutes: 15
    }

    // An empty city means: find the location from the internet connection.
    property Settings weather: Settings {
        location: prefs.location
        category: "weather"
        property string city: prefs.defaults.weather.city
        property real latitude: prefs.defaults.weather.latitude
        property real longitude: prefs.defaults.weather.longitude
        property bool fahrenheit: prefs.defaults.weather.fahrenheit
    }

    property Settings quickButtons: Settings {
        location: prefs.location
        category: "quickButtons"
        property var hidden: []
    }

    // The animation file is kept on reset, like calendar links: it's the user's own pick.
    property Settings idle: Settings {
        location: prefs.location
        category: "idle"
        property string mode: prefs.defaults.idle.mode
        property bool events: prefs.defaults.idle.events
        property bool battery: prefs.defaults.idle.battery
        property bool time: prefs.defaults.idle.time
        property bool weather: prefs.defaults.idle.weather
        property bool animateOnHoverOnly: prefs.defaults.idle.animateOnHoverOnly
        property string animation: ""
    }

    property Settings show: Settings {
        location: prefs.location
        category: "show"
        property bool levels: prefs.defaults.show.levels
        property bool notifications: prefs.defaults.show.notifications
        property bool privacy: prefs.defaults.show.privacy
        property bool devices: prefs.defaults.show.devices
        property bool meetings: prefs.defaults.show.meetings
        property bool power: prefs.defaults.show.power
    }

    // The user's own data, so reset leaves it alone. Links are JSON: [{ name, url }].
    property Settings tools: Settings {
        location: prefs.location
        category: "tools"
        property string links: "[]"
        property var colors: []
    }

    property Settings panel: Settings {
        location: prefs.location
        category: "panel"
        property string extraTool: "clipboard"
    }

    function reset() {
        for (const group in defaults)
            for (const key in defaults[group])
                prefs[group][key] = defaults[group][key]
    }
}
