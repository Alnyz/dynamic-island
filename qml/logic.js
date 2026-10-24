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

function islandState(hasPlayer, hovered, open, hasAlert) {
    if (open)
        return "open"
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

function eventDetail(ev, now) {
    const start = new Date(ev.start)
    const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
    const day = start >= tomorrow ? "Tomorrow" : "Today"
    if (ev.allDay)
        return day
    const mins = Math.round((new Date(ev.end) - start) / 60000)
    const h = Math.floor(mins / 60)
    const m = mins % 60
    return day + " · " + (h > 0 ? h + " h" + (m > 0 ? " " + m + " min" : "") : m + " min")
}

// Countdowns round up, so 4:59.9 still reads 5:00 and 0:00 only shows at the end.
function countdownText(ms) {
    return formatTime(Math.ceil(ms / 1000) * 1000000)
}

// Touchpads send many small wheel deltas; step once per 120 units (one mouse notch).
function wheelSteps(accum, delta) {
    const total = accum + delta
    const steps = total > 0 ? Math.floor(total / 120) : Math.ceil(total / 120)
    return { steps: steps, accum: total - steps * 120 }
}

// Things currently going on, in the order the closed pill cycles through them.
function activities(hasPlayer, timerActive) {
    const list = []
    if (hasPlayer)
        list.push("music")
    if (timerActive)
        list.push("timer")
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
// low battery, then the time and weather the user chose.
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
    const showTime = !!o.show.time
    const showWeather = !!o.show.weather && !isNaN(o.temperature)
    if (!showTime && !showWeather)
        return { kind: "none" }
    const time = String(o.now.getHours()).padStart(2, "0") + ":" + String(o.now.getMinutes()).padStart(2, "0")
    return { kind: "clock", time: time, showTime: showTime, showWeather: showWeather }
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
function alertSize(kind, barHeight, radius) {
    if (kind === "notification")
        return { w: 400, h: 64, r: 22 }
    if (kind === "device")
        return { w: 330, h: 72, r: 24 }
    return { w: 300, h: barHeight, r: radius }
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
