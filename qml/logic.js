.pragma library

// Same values as PlaybackStatus.Status in org.kde.plasma.private.mpris.
var Status = { Unknown: 0, Stopped: 1, Playing: 2, Paused: 3 }

// Quick links are kept as JSON text in the config; a bad value means no links.
function parseLinks(json) {
    try {
        const list = JSON.parse(json || "[]")
        return Array.isArray(list) ? list.filter(l => l && l.url) : []
    } catch (e) {
        return []
    }
}

// What the user typed into an address: a folder path, ~/path, or a site with or without https://.
function linkUrl(input, homeUrl) {
    const s = String(input).trim()
    if (s.startsWith("~/"))
        return homeUrl.replace(/\/$/, "") + s.substring(1)
    if (s.startsWith("/"))
        return "file://" + s
    return /^[a-z][a-z0-9+.-]*:/i.test(s) ? s : "https://" + s
}

// A short name for a link nobody named: the folder's name or the site without www.
function linkName(url) {
    if (url.startsWith("file://"))
        return decodeURIComponent(url.replace(/\/$/, "").split("/").pop()) || "/"
    const host = url.replace(/^[a-z][a-z0-9+.-]*:\/\//i, "").split(/[/?#]/)[0]
    return host.replace(/^www\./, "")
}

// Newest first, no repeats.
function pushColor(list, hex, max) {
    return [hex].concat(list.filter(c => c !== hex)).slice(0, max || 12)
}

function colorFormats(hex) {
    const n = parseInt(hex.substring(1), 16)
    const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255
    const max = Math.max(r, g, b) / 255, min = Math.min(r, g, b) / 255
    const l = (max + min) / 2
    const d = max - min
    let h = 0
    if (d > 0) {
        const rr = r / 255, gg = g / 255, bb = b / 255
        h = max === rr ? ((gg - bb) / d) % 6 : max === gg ? (bb - rr) / d + 2 : (rr - gg) / d + 4
        h = Math.round(h * 60 + 360) % 360
    }
    const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1))
    return {
        hex: hex.toUpperCase(),
        rgb: "rgb(" + r + ", " + g + ", " + b + ")",
        hsl: "hsl(" + h + ", " + Math.round(s * 100) + "%, " + Math.round(l * 100) + "%)"
    }
}

// MPRIS LoopStatus / ShuffleStatus as Plasma's model numbers them.
var Loop = { Unknown: 0, None: 1, Playlist: 2, Track: 3 }
var Shuffle = { Unknown: 0, Off: 1, On: 2 }

// Repeat button cycles off → all → one, like most players.
function nextLoop(status) {
    return status === Loop.None ? Loop.Playlist : status === Loop.Playlist ? Loop.Track : Loop.None
}

var PAUSE_TIMEOUT_MS = 300000

// The players to choose between in the Music tab. Plasma's list repeats the active player (its
// "multiplexer" row comes first, with the same name) and may hold playerctld, which mirrors
// another player; each real player is kept once, as its own (last) row.
function distinctPlayers(players) {
    const byName = new Map()
    for (const p of players || []) {
        const name = p.objectName || p.identity || ""
        if (!name || name === "playerctld" || name.indexOf("playerctld.") === 0)
            continue
        byName.set(name, p)
    }
    return Array.from(byName.values())
}

// The cover to show for the current song. Browsers (Plasma's browser integration) often send a
// skipped-to song with no cover, and can take a cover away again moments after sending it, so a
// cover is kept until the song changes. A new song never inherits the previous song's cover.
// held: { key, url } from the last call; now: { key, url } as the player reports it.
function heldArt(held, now) {
    if (now.url)
        return { key: now.key, url: now.url }
    if (held && held.key === now.key)
        return held
    return { key: now.key, url: "" }
}

// Words without punctuation, so "Dancin’" and "Dancin'" compare equal. Letters of any script stay;
// QML's JavaScript has no \p{L}, so punctuation is named by range: ASCII, Latin-1, General and CJK punctuation.
function coverWords(s) {
    return String(s || "").toLowerCase()
        .replace(/['\u2018\u2019\u02bc]/g, "")
        .replace(/[\u0000-\u002f\u003a-\u0040\u005b-\u0060\u007b-\u00bf\u2000-\u206f\u3000-\u303f]+/g, " ")
        .replace(/\s+/g, " ").trim()
}

// A title without "(Official Video)", "[Radio Edit]", "| YouTube Music" and the like.
function coverBaseTitle(title) {
    return coverWords(String(title || "")
        .replace(/\s*[|-]\s*(YouTube Music|YouTube)\s*$/i, "")
        .replace(/\s*[(\[][^)\]]*[)\]]/g, ""))
}

// iTunes search for a song that came without a cover. Only the artist and title are sent.
function coverSearchUrl(artist, title) {
    const term = (String(artist || "") + " " + String(title || "").replace(/\s*[(\[][^)\]]*[)\]]/g, "")).trim()
    return "https://itunes.apple.com/search?media=music&entity=song&limit=10&term=" + encodeURIComponent(term)
}

// The cover of the first result with the same artist and title, at 600 px; "" if none matches.
// A wrong cover is worse than none, so a result from the right artist but another song is skipped.
function pickCover(results, artist, title) {
    const a = coverWords(artist)
    const t = coverBaseTitle(title)
    if (!a || !t)
        return ""
    for (const r of results || []) {
        const ra = coverWords(r.artistName)
        if (!ra || !(ra.includes(a) || a.includes(ra)))
            continue
        if (coverBaseTitle(r.trackName) !== t || !r.artworkUrl100)
            continue
        return String(r.artworkUrl100).replace(/\/\d+x\d+bb\./, "/600x600bb.")
    }
    return ""
}

function pickPlayer(entries, nowMs, timeoutMs) {
    if (timeoutMs === undefined)
        timeoutMs = PAUSE_TIMEOUT_MS
    var best = -1
    var bestPaused = -1
    for (var i = 0; i < entries.length; ++i) {
        var e = entries[i]
        if (!e.title)
            continue
        if (e.status === Status.Playing) {
            if (best < 0 || e.playingSinceMs > entries[best].playingSinceMs)
                best = i
        } else if (e.status === Status.Paused && nowMs - e.pausedSinceMs < timeoutMs) {
            if (bestPaused < 0 || e.pausedSinceMs > entries[bestPaused].pausedSinceMs)
                bestPaused = i
        }
    }
    return best >= 0 ? best : bestPaused
}

function islandState(hasPlayer, hovered, open, hasAlert, menu, tour) {
    if (open)
        return "open"
    if (tour)
        return "tour"
    if (menu)
        return "menu"
    if (hasAlert)
        return "alert"
    if (!hasPlayer)
        return "idle"
    return hovered ? "peek" : "compact"
}

function formatTime(us) {
    var total = Math.floor(us / 1000000)
    if (!(total > 0))
        return "0:00"
    var h = Math.floor(total / 3600)
    var m = Math.floor(total / 60) % 60
    var s = String(total % 60).padStart(2, "0")
    return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + s : m + ":" + s
}

// Whole weeks from the Sunday on or before the 1st, only as many as the month needs.
function monthGrid(year, month0) {
    const first = new Date(year, month0, 1)
    const start = new Date(year, month0, 1 - first.getDay())
    const cells = []
    const days = new Date(year, month0 + 1, 0).getDate()
    const count = Math.ceil((first.getDay() + days) / 7) * 7
    for (let i = 0; i < count; ++i) {
        const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
        cells.push({ y: d.getFullYear(), m: d.getMonth(), d: d.getDate(), inMonth: d.getMonth() === month0 })
    }
    return cells
}

// The left column of Up next: start time, or "All day".
function eventWhen(ev) {
    if (ev.allDay)
        return "All day"
    const start = new Date(ev.start)
    return String(start.getHours()).padStart(2, "0") + ":" + String(start.getMinutes()).padStart(2, "0")
}

// The battery ring's tooltip: "82% · Charging · 1 h 20 min until full", "45% · 2 h 5 min left",
// "100% · Fully charged". state is the battery's sysfs status; minutes -1 when unknown.
function batteryTooltip(percent, state, minutes) {
    const time = minutes >= 0 ? (minutes >= 60 ? Math.floor(minutes / 60) + " h" + (minutes % 60 ? " " + (minutes % 60) + " min" : "") : minutes + " min") : ""
    const parts = [percent + "%"]
    if (state === "Full" || (state !== "Discharging" && percent >= 100))
        parts.push("Fully charged")
    else if (state === "Charging")
        parts.push(time ? "Charging · " + time + " until full" : "Charging")
    else if (state === "Not charging")
        parts.push("Plugged in, not charging")
    else if (state === "Discharging")
        parts.push(time ? time + " left" : "On battery")
    return parts.join(" · ")
}

// Countries with a public holiday calendar from Google, and the region code that picks each
// one automatically from the system's language setting (en_IN -> India).
var HOLIDAY_COUNTRIES = [
    { key: "indian", label: "India", region: "IN" }, { key: "usa", label: "United States", region: "US" },
    { key: "uk", label: "United Kingdom", region: "GB" }, { key: "canadian", label: "Canada", region: "CA" },
    { key: "australian", label: "Australia", region: "AU" }, { key: "new_zealand", label: "New Zealand", region: "NZ" },
    { key: "irish", label: "Ireland", region: "IE" }, { key: "german", label: "Germany", region: "DE" },
    { key: "french", label: "France", region: "FR" }, { key: "japanese", label: "Japan", region: "JP" },
    { key: "china", label: "China", region: "CN" }, { key: "singapore", label: "Singapore", region: "SG" },
    { key: "malaysia", label: "Malaysia", region: "MY" }, { key: "indonesian", label: "Indonesia", region: "ID" },
    { key: "philippines", label: "Philippines", region: "PH" }, { key: "ae", label: "United Arab Emirates", region: "AE" },
    { key: "pk", label: "Pakistan", region: "PK" }, { key: "bd", label: "Bangladesh", region: "BD" },
    { key: "lk", label: "Sri Lanka", region: "LK" }, { key: "np", label: "Nepal", region: "NP" },
    { key: "sa", label: "South Africa", region: "ZA" }
]

// The holiday calendar to show: pref is a country key, "" for none, or "auto" to go by the
// locale name (like "en_IN").
function holidayCountry(pref, localeName) {
    if (pref !== "auto")
        return pref || ""
    const region = String(localeName || "").split(/[_.@-]/)[1] || ""
    const c = HOLIDAY_COUNTRIES.find(x => x.region === region.toUpperCase())
    return c ? c.key : ""
}

function holidayLabel(key) {
    const c = HOLIDAY_COUNTRIES.find(x => x.key === key)
    return c ? c.label : ""
}

// Google's public iCal feed of a country's holidays and observances.
function holidayUrl(key) {
    return key ? "https://calendar.google.com/calendar/ical/en." + key + "%23holiday%40group.v.calendar.google.com/public/basic.ics" : ""
}

// Holiday-calendar events tagged as such; observances (festivals, religious days) only when wanted.
function holidayEvents(events, observances) {
    const out = []
    for (const e of events || []) {
        const isPublic = e.note === "Public holiday"
        if (!isPublic && !observances)
            continue
        out.push(Object.assign({}, e, { holiday: true, publicHoliday: isPublic, link: "" }))
    }
    return out
}

// Two event lists as one, in start order.
function mergeEvents(a, b) {
    return (a || []).concat(b || []).sort((x, y) => new Date(x.start) - new Date(y.start))
}

var WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

// "Today", "Tomorrow", "Yesterday", or "Thu 12 Nov" for any other day.
function dayName(date, now) {
    const d = new Date(date)
    const days = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000)
    if (days === 0)
        return "Today"
    if (days === 1)
        return "Tomorrow"
    if (days === -1)
        return "Yesterday"
    return WEEKDAYS[d.getDay()] + " " + d.getDate() + " " + MONTHS[d.getMonth()]
}

// "Today · 45 min"; without the day (a picked day's list has it in its heading) just "45 min".
function eventDetail(ev, now, withoutDay) {
    const start = new Date(ev.start)
    const day = dayName(start, now)
    if (ev.allDay)
        return withoutDay ? "All day" : day
    const mins = Math.round((new Date(ev.end) - start) / 60000)
    const h = Math.floor(mins / 60)
    const m = mins % 60
    const length = h > 0 ? h + " h" + (m > 0 ? " " + m + " min" : "") : m + " min"
    return withoutDay ? length : day + " · " + length
}

// Countdowns round up, so 4:59.9 still reads 5:00 and 0:00 only shows at the end.
function countdownText(ms) {
    return formatTime(Math.ceil(ms / 1000) * 1000000)
}

// Touchpads send many small wheel deltas; step once per 120 units (one mouse notch).
// Speaker volume after scrolling over the pill: 5% per step, between silent and 100%.
// normal is the device's 100% (PulseAudio's PA_VOLUME_NORM, 65536).
function volumeAfterSteps(volume, steps, normal) {
    return Math.round(Math.max(0, Math.min(normal, volume + steps * normal * 0.05)))
}

// Minutes to add when scrolling over the timer; taking time off never leaves less than a minute.
function timerStepMinutes(remainingMs, steps) {
    if (steps >= 0)
        return steps
    const most = Math.floor((remainingMs - 60000) / 60000)
    return -Math.min(-steps, Math.max(0, most))
}

// A vertical scroll as "up is more", whatever the touchpad's setting: with natural scrolling
// (inverted) Qt reports the content's direction, so moving fingers down reads as up.
function scrollAmount(angleDeltaY, inverted) {
    return inverted ? -angleDeltaY : angleDeltaY
}

// Whether a device is muted after its volume is set: reaching 0 mutes (so the keyboard's mute
// light comes on, like Plasma's own volume control), turning it up from muted unmutes.
function mutedAfter(volume, wasMuted, raised) {
    if (volume <= 0)
        return true
    return raised ? false : wasMuted
}

function wheelSteps(accum, delta) {
    const total = accum + delta
    const steps = total > 0 ? Math.floor(total / 120) : Math.ceil(total / 120)
    return { steps: steps, accum: total - steps * 120 }
}

// Things currently going on, in the order the closed pill cycles through them.
function activities(hasPlayer, timerActive, hasJobs) {
    const list = []
    if (hasPlayer)
        list.push("music")
    if (timerActive)
        list.push("timer")
    if (hasJobs)
        list.push("jobs")
    return list
}

// A name for a calendar link that leaves out its secret part.
function calendarLabel(url) {
    const m = /^https?:\/\/([^/]+)(\/.*)?$/.exec(url)
    if (!m)
        return "Calendar"
    const google = /\/ical\/([^/]+)\//.exec(m[2] || "")
    return google ? decodeURIComponent(google[1]) : m[1]
}

// QSettings reads a one-item list back as a plain string, and a longer one as a QStringList.
function toList(value) {
    if (!value)
        return []
    return typeof value === "string" ? [value] : Array.from(value)
}

// What the idle pill shows, most urgent first: an event starting within 30 minutes,
// low battery, then the time and weather the user chose, plus the pending update count when there is one.
function idleGlance(o) {
    const ev = o.event
    if (o.show.events && ev && !ev.allDay) {
        const start = new Date(ev.start)
        const mins = Math.ceil((start - o.now) / 60000)
        if (new Date(ev.end) > o.now && mins <= 30)
            return { kind: "event", title: ev.title, detail: mins <= 0 ? "now" : "in " + mins + " min", link: ev.link || "" }
    }
    if (o.show.battery && o.battery >= 0 && o.battery <= 15 && !o.charging)
        return { kind: "batteryLow", title: o.battery + "%", detail: "plug in" }
    const low = lowDevice(o.devices)
    if (o.show.battery && low)
        return { kind: "deviceLow", title: low.name, detail: low.battery + "%", icon: low.icon || "bluetooth" }
    if (o.show.todo !== false && o.todo && o.todo.text)
        return { kind: "todo", id: o.todo.id, title: o.todo.text, detail: "" }
    const showTime = !!o.show.time
    const showWeather = !!o.show.weather && !isNaN(o.temperature)
    const showBattery = !!o.show.battery && o.battery >= 0
    if (!showTime && !showWeather && !showBattery)
        return { kind: "none" }
    const time = String(o.now.getHours()).padStart(2, "0") + ":" + String(o.now.getMinutes()).padStart(2, "0")
    const updates = o.show.updates && o.updates > 0 ? o.updates : 0
    return { kind: "clock", time: time, showTime: showTime, showWeather: showWeather, showBattery: showBattery, updates: updates }
}

// "Ryzen HD Audio Controller Speaker" → "Speaker": the port name when the device name ends with it.
function deviceLabel(description, portDescription) {
    return portDescription && description.endsWith(portDescription) ? portDescription : description
}

var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function dayStart(ms) {
    const d = new Date(ms)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
}

function shortDate(ms) {
    const d = new Date(ms)
    return d.getDate() + " " + MONTHS[d.getMonth()]
}

// Clipboard row times: "now", "9 min", "2 h", then "Yesterday" or "20 Oct".
function ago(ms, nowMs) {
    const mins = Math.floor((nowMs - ms) / 60000)
    if (mins < 1)
        return "now"
    if (mins < 60)
        return mins + " min"
    if (ms >= dayStart(nowMs))
        return Math.floor(mins / 60) + " h"
    if (ms >= dayStart(nowMs) - 86400000)
        return "Yesterday"
    return shortDate(ms)
}

function noteWhen(ms, nowMs) {
    if (ms >= dayStart(nowMs)) {
        const d = new Date(ms)
        return "Today " + String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
    }
    return ms >= dayStart(nowMs) - 86400000 ? "Yesterday" : shortDate(ms)
}

function clipMeta(item, nowMs) {
    const a = ago(item.time, nowMs)
    const when = a === "now" ? "just now" : a.endsWith(" min") || a.endsWith(" h") ? a + " ago" : a
    if (item.kind === "image")
        return "Image · " + item.width + " × " + item.height + " · " + when
    if (item.kind === "link")
        return "Link · " + when
    return "Text · " + item.text.length + " characters · " + when
}

// The clipboard list: pinned first, then recent, each under a header; kind is "all", "text", "link" or "image".
function clipRows(items, query, kind) {
    const q = query.toLowerCase()
    const match = items.filter(it => (kind === "all" || it.kind === kind)
        && (q === "" || (it.text || "").toLowerCase().includes(q)))
    const rows = []
    const pinned = match.filter(it => it.pinned)
    const recent = match.filter(it => !it.pinned)
    if (pinned.length)
        rows.push({ header: "Pinned" }, ...pinned)
    if (recent.length)
        rows.push({ header: "Recent" }, ...recent)
    return rows
}

// The pill's size while it shows an alert.
// The first-run tour, one card per step.
var TOUR = [
    { icon: "input-keyboard", title: "Open the panel", body: "Click the island, or press Meta+N from anywhere. Esc or Meta+N closes it." },
    { icon: "input-touchpad", title: "Gestures on the pill", body: "Swipe sideways to switch turns; scroll for volume. Middle-click plays or pauses, double-click skips." },
    { icon: "configure", title: "Quick menu and settings", body: "Right-click for timers, do not disturb or hiding. The gear in the panel opens Settings." }
]

// What a Pomodoro phase change says: { title, body } for the notification.
function pomodoroMessage(ended, next, minutes) {
    if (next === "work")
        return { title: "Back to focus", body: minutes + " minutes of focus" }
    return { title: ended === "work" ? "Time for a break" : "Break", body: (next === "longBreak" ? "A long break: " : "") + minutes + " minutes" }
}

// A connected Bluetooth device at 15% or less (the emptiest), or null.
function lowDevice(devices) {
    let low = null
    for (const d of devices || [])
        if (d.battery >= 0 && d.battery <= 15 && (!low || d.battery < low.battery))
            low = d
    return low
}

// The Bluetooth quick button's badge and tooltip: { badge: "80" or "", label }.
function bluetoothSummary(devices) {
    const list = devices || []
    const withBattery = list.filter(d => d.battery >= 0)
    const shown = withBattery.length ? withBattery.reduce((a, b) => (b.battery < a.battery ? b : a)) : null
    const names = list.map(d => d.name + (d.battery >= 0 ? " " + d.battery + "%" : ""))
    return { badge: shown ? String(shown.battery) : "", label: names.length ? "Bluetooth · " + names.join(", ") : "Bluetooth" }
}

// The island's colours for each theme, as Qt palette roles.
// The island's opacity in percent. opacity < 0 means never set: islands that had the old
// see-through switch on keep its 78%, others are solid.
function islandOpacity(opacity, translucent) {
    return opacity >= 0 ? Math.max(20, Math.min(100, opacity)) : translucent ? 78 : 100
}

// Relative luminance (WCAG) of a colour, 0 (black) to 1 (white).
function luminance(c) {
    const q = Qt.color(c)
    const ch = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    return 0.2126 * ch(q.r) + 0.7152 * ch(q.g) + 0.0722 * ch(q.b)
}

function contrastRatio(a, b) {
    const x = luminance(a), y = luminance(b)
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
}

// Whether text on this background reads better dark than light.
function wantsDarkText(background) {
    return contrastRatio(background, "#000000") > contrastRatio(background, "#ffffff")
}

// The island's colours for a theme, or built around a custom background colour: its surfaces are
// shades of it, and its text is dark or light, whichever reads better on it.
function themeColors(light, custom) {
    if (custom) {
        const bg = Qt.color(custom)
        const dark = wantsDarkText(bg)
        // A softened black, unless the background is a mid-tone that needs the full contrast.
        const ink = !dark ? "#ffffff" : contrastRatio("#111113", bg) >= 4.5 ? "#111113" : "#000000"
        const toward = (c, a) => Qt.tint(bg, Qt.rgba(c, c, c, a))
        const mix = a => toward(dark ? 0 : 1, a)
        // Raised surfaces normally shade toward the text; on mid-tones, with little contrast to
        // spare, they shade away from it instead so the text on them stays readable.
        const roomy = contrastRatio(ink, bg) >= 7
        const surface = a => roomy ? mix(a) : toward(dark ? 1 : 0, a * 1.6)
        return {
            window: Qt.rgba(bg.r, bg.g, bg.b, 1), windowText: ink, text: mix(0.86), placeholderText: mix(0.68),
            mid: mix(0.55), base: surface(0.07), alternateBase: surface(0.11), button: surface(0.16), dark: surface(0.24),
            brightText: dark ? "#3d2c05" : "#f1ebd9", light: dark
        }
    }
    return light ? {
        window: "#f2f2f7", windowText: "#1c1c1e", text: "#2c2c2e", placeholderText: "#6e6e73", mid: "#8e8e93",
        base: "#ffffff", alternateBase: "#e9e9ee", button: "#dedee3", dark: "#c7c7cc", brightText: "#7a5c12"
    } : {
        window: "#000000", windowText: "#ffffff", text: "#e5e9f0", placeholderText: "#9aa3ad", mid: "#8a929c",
        base: "#141414", alternateBase: "#1c1c1c", button: "#262626", dark: "#333333", brightText: "#e8e2d0"
    }
}

// Rows of the right-click menu on the pill. s: { dnd, hidden }.
function pillMenu(s) {
    return [
        s.dnd ? { key: "dnd-off", label: "Resume notifications", icon: "notifications" }
              : { key: "dnd-hour", label: "Pause notifications for 1 hour", icon: "notifications-disabled" },
        { key: "timers", label: "Timer", icon: "chronometer", minutes: [5, 10, 25] },
        s.hidden ? { key: "show", label: "Show the island", icon: "view-visible" }
                 : { key: "hide-hour", label: "Hide for 1 hour", icon: "view-hidden" },
        { key: "settings", label: "Settings", icon: "configure" }
    ]
}

// Height (3..14 px) of one of the pill's four level bars for a sound level of 0..1. Each bar has
// its own reach, swayed by phase so they don't move as one. Peaks are lifted (square root)
// since music rarely sits near full scale.
function barHeight(level, index, phase) {
    const reach = [0.85, 1.0, 0.92, 0.78][index % 4]
    const sway = 0.85 + 0.15 * Math.sin(phase + index * 1.7)
    const v = Math.sqrt(Math.max(0, Math.min(1, level))) * reach * sway
    return 3 + Math.round(v * 11 * 10) / 10
}

// --- Lyrics (LRCLIB) ---

// The exact lookup: LRCLIB matches title, artist and length (within a couple of seconds).
function lyricsGetUrl(artist, title, album, lengthUs) {
    let url = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(artist || "") + "&track_name=" + encodeURIComponent(title || "")
    if (album)
        url += "&album_name=" + encodeURIComponent(album)
    if (lengthUs > 0)
        url += "&duration=" + Math.round(lengthUs / 1e6)
    return url
}

// The fallback when the exact lookup finds nothing: a looser search.
function lyricsSearchUrl(artist, title) {
    const t = String(title || "").replace(/\s*[|-]\s*(YouTube Music|YouTube)\s*$/i, "").replace(/\s*[(\[][^)\]]*[)\]]/g, "")
    return "https://lrclib.net/api/search?artist_name=" + encodeURIComponent(artist || "") + "&track_name=" + encodeURIComponent(t.trim())
}

// The best search result: same artist and title, length within 10 s when known, timed lyrics first.
function pickLyrics(results, artist, title, lengthUs) {
    const a = coverWords(artist)
    const t = coverBaseTitle(title)
    const len = lengthUs > 0 ? lengthUs / 1e6 : 0
    let best = null
    let bestScore = -1
    for (const r of results || []) {
        const ra = coverWords(r.artistName)
        if (!a || !ra || !(ra.includes(a) || a.includes(ra)) || coverBaseTitle(r.trackName) !== t)
            continue
        if (!r.syncedLyrics && !r.plainLyrics && !r.instrumental)
            continue
        const off = len > 0 && r.duration > 0 ? Math.abs(r.duration - len) : 0
        if (off > 10)
            continue
        const score = (r.syncedLyrics ? 100 : 0) + (r.plainLyrics ? 10 : 0) - off
        if (score > bestScore) {
            best = r
            bestScore = score
        }
    }
    return best
}

// "[01:02.50]Words" lines -> [{ ms, text }] by time. A line may carry several time tags;
// tags like [ar:...] and lines without a time are skipped.
function parseLrc(text) {
    const out = []
    const tag = /\[(\d+):(\d{1,2})(?:[.:](\d{1,3}))?\]/g
    for (const raw of String(text || "").split(/\r?\n/)) {
        const times = []
        let m
        let last = 0
        tag.lastIndex = 0
        while ((m = tag.exec(raw)) !== null) {
            const frac = m[3] ? Number((m[3] + "00").slice(0, 3)) : 0
            times.push(Number(m[1]) * 60000 + Number(m[2]) * 1000 + frac)
            last = tag.lastIndex
        }
        if (!times.length)
            continue
        const words = raw.slice(last).trim()
        for (const ms of times)
            out.push({ ms: ms, text: words })
    }
    return out.sort((x, y) => x.ms - y.ms)
}

// Index of the line being sung at ms: the last one that has started, or -1 before the first.
function lyricLine(lines, ms) {
    let lo = 0, hi = lines.length - 1, found = -1
    while (lo <= hi) {
        const mid = (lo + hi) >> 1
        if (lines[mid].ms <= ms) {
            found = mid
            lo = mid + 1
        } else {
            hi = mid - 1
        }
    }
    return found
}

// a: the alert itself, for kinds whose size depends on it (a notification with buttons is taller).
function alertSize(kind, barHeight, radius, a) {
    if (kind === "notification" && a && a.buttons && a.buttons.length > 0)
        return { w: 400, h: 100, r: 24 }
    if (kind === "notification" || kind === "job")
        return { w: 400, h: 64, r: 22 }
    if (kind === "device")
        return { w: 330, h: 72, r: 24 }
    if (kind === "privacy")
        return { w: 330, h: barHeight, r: radius }
    return { w: 300, h: barHeight, r: radius }
}

// Whether an alert may come in front of a full-screen app.
// f: { levels, jobs, privacy, devices, power, allNotifications, urgent: [keys] }
function fullScreenAllowed(a, f) {
    switch (a.kind) {
    case "volume":
    case "brightness":
    case "capslock": return !!f.levels
    case "job": return !!f.jobs
    case "privacy": return !!f.privacy
    case "device": return !!f.devices
    case "power": return !!f.power
    case "notification": return !!f.allNotifications || a.urgency === 2 || toList(f.urgent).includes(notifKey(a))
    default: return true
    }
}

// Apps in after that weren't in before, e.g. ones that just started recording.
function newApps(before, after) {
    return after.filter(name => !before.includes(name))
}

// Apps recording from a microphone, leaving out the island's own level meter and Plasma's.
function recordingApps(streams) {
    const names = []
    for (const s of streams) {
        if (s.virtualStream)
            continue
        const name = (s.client && s.client.name) || (s.properties && s.properties["application.name"]) || ""
        if (name && name !== "dynamic-island" && name !== "plasmashell" && !names.includes(name))
            names.push(name)
    }
    return names
}

function privacyText(mic, camera) {
    const parts = []
    if (mic.length)
        parts.push("Microphone: " + mic.join(", "))
    if (camera.length)
        parts.push("Camera: " + camera.join(", "))
    return parts.join(" · ")
}

// Jobs are the progress reports apps send to Plasma's job tracker; each update carries only what changed.
function jobMerge(job, props, nowMs) {
    const next = Object.assign({ startMs: nowMs }, job, props)
    if (next.percent !== undefined)
        next.percent = Math.max(0, Math.min(100, Number(next.percent) || 0))
    return next
}

// Local paths come in raw, so only URLs drop their query and get decoded.
function lastSegment(s) {
    let path = String(s || "")
    const url = /^[a-z]+:\/\//i.test(path)
    if (url)
        path = path.split(/[?#]/)[0]
    const last = path.replace(/\/+$/, "").split("/").pop() || ""
    try {
        return url ? decodeURIComponent(last) : last
    } catch (e) {
        return last
    }
}

// An extraction's destination is a folder, so it is named after its archive instead.
function jobName(job) {
    const first = job.title === "Extracting Files" ? [job.descriptionValue1, job.descriptionValue2] : [job.descriptionValue2, job.descriptionValue1]
    return lastSegment(first[0]) || lastSegment(first[1]) || job.title || "File"
}

function jobVerb(job) {
    const folder = lastSegment(job.destUrl)
    return job.title === "Copying" && folder ? "Copying to " + folder : job.title || ""
}

function jobTimeLeft(job) {
    if (!(job.speed > 0) || !(job.totalBytes > 0) || job.processedBytes === undefined)
        return ""
    const secs = Math.ceil((job.totalBytes - job.processedBytes) / job.speed)
    if (secs < 60)
        return Math.max(1, secs) + " s"
    const mins = Math.ceil(secs / 60)
    return mins < 60 ? mins + " min" : Math.floor(mins / 60) + " h " + (mins % 60) + " min"
}

// Jobs younger than 2 s are left out: a rename or a small copy would only flicker.
function jobsSummary(jobs, nowMs) {
    const shown = Object.values(jobs).filter(j => nowMs - j.startMs >= 2000).sort((a, b) => a.startMs - b.startMs)
    if (!shown.length)
        return { shown: [], count: 0, percent: 0 }
    const bytes = shown.every(j => j.totalBytes > 0)
    const percent = bytes ? shown.reduce((a, j) => a + (j.processedBytes || 0), 0) / shown.reduce((a, j) => a + j.totalBytes, 0) * 100
                          : shown.reduce((a, j) => a + (j.percent || 0), 0) / shown.length
    return { shown: shown, count: shown.length, percent: Math.round(percent) }
}

var JOB_DONE = { "Downloading": "Downloaded", "Copying": "Copied", "Moving": "Moved", "Extracting Files": "Extracted" }
var JOB_FAIL = { "Downloading": "Download failed", "Copying": "Copy failed", "Moving": "Move failed", "Extracting Files": "Extraction failed" }

function jobDoneTitle(job) {
    return JOB_DONE[job.title] || job.title || ""
}

function jobFailTitle(job) {
    return JOB_FAIL[job.title] || (job.title || "Job") + " failed"
}

function formatSize(bytes) {
    if (bytes >= 1e9)
        return (bytes / 1e9).toFixed(1) + " GB"
    return bytes >= 1e6 ? Math.round(bytes / 1e6) + " MB" : Math.round(bytes / 1e3) + " KB"
}

// Notification history. Plasma's own parts count as System; anything without a desktop entry
// (notify-send, scripts) is Others and is told apart by its app name.
var SYSTEM_ENTRIES = ["org.kde.plasmashell", "org.kde.kdeconnect.daemon", "org.kde.kdeconnect.app", "org.kde.discover",
    "org.kde.discover.notifier", "org.kde.powerdevil", "org.kde.kded6", "org.kde.kwin", "org.kde.kscreen",
    "org.kde.bluedevil", "org.kde.plasma.networkmanagement", "org.freedesktop.network-manager-applet"]
var HISTORY_MAX = 200

function notifKind(n) {
    if (!n.desktopEntry)
        return "others"
    return SYSTEM_ENTRIES.includes(n.desktopEntry) ? "system" : "apps"
}

function notifKey(n) {
    return n.desktopEntry || "app:" + n.app
}

// h: { save, system, apps, others, off: [keys] }
function historyAllowed(n, h) {
    return !!h.save && !!h[notifKind(n)] && !toList(h.off).includes(notifKey(n))
}

// Plasma's ids aren't tracked, so an update replaces the newest row from the same app.
function historyAdd(items, n, nowMs, days) {
    const key = notifKey(n)
    const at = n.replaces > 0 ? items.findIndex(r => r.key === key) : -1
    const row = at >= 0
        ? Object.assign({}, items[at], { title: n.title, body: n.body, icon: n.icon, time: nowMs, seen: false })
        : { id: nowMs + "-" + Math.random().toString(36).slice(2, 8), key: key, app: n.app, desktopEntry: n.desktopEntry, icon: n.icon,
            origin: n.origin || "", title: n.title, body: n.body, time: nowMs, seen: false }
    return historyPrune([row].concat(items.filter((r, i) => i !== at)), nowMs, days)
}

function historyPrune(items, nowMs, days) {
    return items.filter(r => nowMs - r.time <= days * 86400000).slice(0, HISTORY_MAX)
}

function isNewItem(item, lastSeen) {
    return !item.seen && item.time > lastSeen
}

function newCount(items, lastSeen) {
    return items.filter(r => isNewItem(r, lastSeen)).length
}

// Items are newest first, so groups come out ordered by their newest row.
function historyGroups(items) {
    const groups = []
    const byKey = {}
    for (const r of items) {
        if (!byKey[r.key]) {
            byKey[r.key] = { key: r.key, app: r.app, icon: r.icon, rows: [] }
            groups.push(byKey[r.key])
        }
        byKey[r.key].rows.push(r)
    }
    return groups
}

// The apps seen so far are kept as JSON text in the config, like quick links.
function parseKnownApps(json) {
    try {
        const list = JSON.parse(json || "[]")
        return Array.isArray(list) ? list.filter(a => a && a.key) : []
    } catch (e) {
        return []
    }
}

// The apps listed in Settings; Others have no desktop entry, so they get only the kind switch.
function rememberApp(apps, n) {
    const kind = notifKind(n)
    const key = notifKey(n)
    if (kind === "others" || apps.some(a => a.key === key))
        return apps
    return apps.concat([{ key: key, name: n.app, icon: n.icon, kind: kind }])
}
