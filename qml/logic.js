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
    const showBattery = !!o.show.battery && o.battery >= 0
    if (!showTime && !showWeather && !showBattery)
        return { kind: "none" }
    const time = String(o.now.getHours()).padStart(2, "0") + ":" + String(o.now.getMinutes()).padStart(2, "0")
    return { kind: "clock", time: time, showTime: showTime, showWeather: showWeather, showBattery: showBattery }
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
    if (kind === "notification" || kind === "job")
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
        : { id: nowMs + "-" + items.length, key: key, app: n.app, desktopEntry: n.desktopEntry, icon: n.icon,
            title: n.title, body: n.body, time: nowMs, seen: false }
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

// The apps listed in Settings; Others have no desktop entry, so they get only the kind switch.
function rememberApp(apps, n) {
    const kind = notifKind(n)
    const key = notifKey(n)
    if (kind === "others" || apps.some(a => a.key === key))
        return apps
    return apps.concat([{ key: key, name: n.app, icon: n.icon, kind: kind }])
}
