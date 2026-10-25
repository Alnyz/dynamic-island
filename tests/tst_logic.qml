import QtQuick
import QtTest
import "../qml/logic.js" as L

TestCase {
    name: "logic"

    function test_links() {
        compare(L.parseLinks("not json"), [])
        compare(L.parseLinks('[{"name":"A","url":"https://a.com"},{"name":"no url"}]').length, 1)
        compare(L.linkUrl("example.com", "file:///home/a"), "https://example.com")
        compare(L.linkUrl("http://x.com/p", "file:///home/a"), "http://x.com/p")
        compare(L.linkUrl("~/Documents", "file:///home/a"), "file:///home/a/Documents")
        compare(L.linkUrl("/srv/data", "file:///home/a"), "file:///srv/data")
        compare(L.linkName("https://www.youtube.com/watch?v=1"), "youtube.com")
        compare(L.linkName("file:///home/a/My%20Reports/"), "My Reports")
    }

    function test_colors() {
        compare(L.pushColor(["#111111", "#222222"], "#222222"), ["#222222", "#111111"])
        compare(L.pushColor(["#1", "#2", "#3"], "#4", 3), ["#4", "#1", "#2"])
        const f = L.colorFormats("#ff375f")
        compare(f.hex, "#FF375F")
        compare(f.rgb, "rgb(255, 55, 95)")
        compare(f.hsl, "hsl(348, 100%, 61%)")
        compare(L.colorFormats("#808080").hsl, "hsl(0, 0%, 50%)")
    }

    function test_next_loop() {
        compare(L.nextLoop(L.Loop.None), L.Loop.Playlist)
        compare(L.nextLoop(L.Loop.Playlist), L.Loop.Track)
        compare(L.nextLoop(L.Loop.Track), L.Loop.None)
    }

    function test_pick_empty() { compare(L.pickPlayer([], 0), -1) }

    function test_pick_ignores_stopped_and_untitled() {
        compare(L.pickPlayer([
            { status: L.Status.Stopped, title: "dead", playingSinceMs: 9, pausedSinceMs: 0 },
            { status: L.Status.Playing, title: "", playingSinceMs: 8, pausedSinceMs: 0 },
            { status: L.Status.Playing, title: "Evaluasi", playingSinceMs: 1, pausedSinceMs: 0 }], 10), 2)
    }

    function test_pick_most_recent_playing() {
        compare(L.pickPlayer([
            { status: L.Status.Playing, title: "a", playingSinceMs: 100, pausedSinceMs: 0 },
            { status: L.Status.Playing, title: "b", playingSinceMs: 200, pausedSinceMs: 0 }], 300), 1)
    }

    function test_pick_playing_beats_paused() {
        compare(L.pickPlayer([
            { status: L.Status.Paused, title: "a", playingSinceMs: 0, pausedSinceMs: 500 },
            { status: L.Status.Playing, title: "b", playingSinceMs: 100, pausedSinceMs: 0 }], 600), 1)
    }

    function test_pick_paused_within_timeout() {
        compare(L.pickPlayer([{ status: L.Status.Paused, title: "a", playingSinceMs: 0, pausedSinceMs: 1000 }], 1000 + 299999), 0)
    }

    function test_pick_paused_past_timeout() {
        compare(L.pickPlayer([{ status: L.Status.Paused, title: "a", playingSinceMs: 0, pausedSinceMs: 1000 }], 1000 + 300000), -1)
    }

    function test_island_state() {
        compare(L.islandState(false, true, true), "open")
        compare(L.islandState(false, true, false), "idle")
        compare(L.islandState(true, false, false), "compact")
        compare(L.islandState(true, true, false), "peek")
        compare(L.islandState(true, true, true), "open")
        compare(L.islandState(true, true, false, true), "alert")
        compare(L.islandState(false, false, true, true), "open")
    }

    function test_alert_size() {
        compare(L.alertSize("volume", 32, 12), { w: 300, h: 32, r: 12 })
        compare(L.alertSize("notification", 32, 12), { w: 400, h: 64, r: 22 })
        compare(L.alertSize("job", 32, 12), { w: 400, h: 64, r: 22 })
        compare(L.alertSize("device", 32, 12), { w: 330, h: 72, r: 24 })
    }

    function test_glance_event_carries_link() {
        const now = new Date(2026, 9, 23, 16, 30)
        const g = L.idleGlance({ now: now, show: { events: true }, battery: -1,
            event: { title: "Sync", start: new Date(2026, 9, 23, 16, 33), end: new Date(2026, 9, 23, 17, 0), allDay: false, link: "https://meet.google.com/x" } })
        compare(g.link, "https://meet.google.com/x")
    }

    function test_recording_apps() {
        const streams = [
            { client: { name: "Discord" }, properties: {}, virtualStream: false },
            { client: { name: "dynamic-island" }, properties: {}, virtualStream: false },
            { client: null, properties: { "application.name": "OBS" }, virtualStream: false },
            { client: { name: "plasmashell" }, properties: {}, virtualStream: false },
            { client: { name: "Discord" }, properties: {}, virtualStream: false },
            { client: { name: "Peak" }, properties: {}, virtualStream: true }
        ]
        compare(L.recordingApps(streams), ["Discord", "OBS"])
    }

    function test_privacy_text() {
        compare(L.privacyText(["Discord"], []), "Microphone: Discord")
        compare(L.privacyText(["Discord", "OBS"], ["brave"]), "Microphone: Discord, OBS · Camera: brave")
        compare(L.privacyText([], []), "")
    }

    function test_format_time() {
        compare(L.formatTime(92000000), "1:32")
        compare(L.formatTime(241000000), "4:01")
        compare(L.formatTime(3725000000), "1:02:05")
        compare(L.formatTime(-5), "0:00")
        compare(L.formatTime(NaN), "0:00")
    }

    function test_month_grid_oct_2026() {
        const g = L.monthGrid(2026, 9)
        compare(g.length, 35)
        compare([g[0].y, g[0].m, g[0].d, g[0].inMonth], [2026, 8, 27, false])
        compare([g[4].m, g[4].d, g[4].inMonth], [9, 1, true])
    }

    function test_month_grid_feb_2026() {
        const g = L.monthGrid(2026, 1)
        compare([g[0].m, g[0].d, g[0].inMonth], [1, 1, true])
        compare(g.length, 28)
        compare([g[27].m, g[27].d], [1, 28])
    }

    function test_month_grid_6_rows() {
        const g = L.monthGrid(2026, 7)
        compare([g[0].m, g[0].d], [6, 26])
        compare([g[41].m, g[41].d, g[41].inMonth], [8, 5, false])
    }

    function test_event_label() {
        const now = new Date(2026, 9, 23, 14, 0)
        const ev = (a, b, allDay) => ({ start: a, end: b, allDay: allDay })
        const d = (day, h, m) => new Date(2026, 9, day, h || 0, m || 0)
        compare(L.eventWhen(ev(d(23, 15), d(23, 15, 45), false)), "15:00")
        compare(L.eventDetail(ev(d(23, 15), d(23, 15, 45), false), now), "Today · 45 min")
        compare(L.eventDetail(ev(d(23, 17, 30), d(23, 19), false), now), "Today · 1 h 30 min")
        compare(L.eventDetail(ev(d(24, 9), d(24, 10), false), now), "Tomorrow · 1 h")
        compare(L.eventWhen(ev(d(23), d(24), true)), "All day")
        compare(L.eventDetail(ev(d(23), d(24), true), now), "Today")
        compare(L.eventDetail(ev(d(24), d(25), true), now), "Tomorrow")
    }

    function test_countdown_text_rounds_up() {
        compare(L.countdownText(300000), "5:00")
        compare(L.countdownText(298990), "4:59")
        compare(L.countdownText(500), "0:01")
        compare(L.countdownText(0), "0:00")
    }

    function test_wheel_steps() {
        let r = L.wheelSteps(0, 30)
        compare(r.steps, 0)
        r = L.wheelSteps(r.accum, 100)
        compare(r.steps, 1)
        compare(r.accum, 10)
        r = L.wheelSteps(0, -240)
        compare(r.steps, -2)
        r = L.wheelSteps(0, 0)
        compare(r.steps, 0)
    }

    function test_activities() {
        compare(L.activities(false, false), [])
        compare(L.activities(true, false), ["music"])
        compare(L.activities(false, true), ["timer"])
        compare(L.activities(true, true), ["music", "timer"])
        compare(L.activities(true, true, true), ["music", "timer", "jobs"])
        compare(L.activities(false, false, true), ["jobs"])
    }

    function test_pick_paused_custom_timeout() {
        const e = [{ status: L.Status.Paused, title: "a", playingSinceMs: 0, pausedSinceMs: 1000 }]
        compare(L.pickPlayer(e, 1000 + 59999, 60000), 0)
        compare(L.pickPlayer(e, 1000 + 60000, 60000), -1)
    }

    function test_calendar_label_hides_secret() {
        compare(L.calendarLabel("https://calendar.google.com/calendar/ical/someone%40gmail.com/private-abc123/basic.ics"), "someone@gmail.com")
        compare(L.calendarLabel("https://example.com/cal.ics"), "example.com")
        compare(L.calendarLabel("not a link"), "Calendar")
    }

    function test_to_list() {
        compare(L.toList(undefined), [])
        compare(L.toList(""), [])
        compare(L.toList("a"), ["a"])
        compare(L.toList(["a", "b"]), ["a", "b"])
    }

    function test_idle_glance_order() {
        const now = new Date(2026, 9, 23, 16, 35)
        const all = { events: true, battery: true, time: true, weather: true }
        const soon = { title: "Gym", start: new Date(2026, 9, 23, 17, 0), end: new Date(2026, 9, 23, 18, 0), allDay: false }
        const base = { now: now, show: all, event: null, battery: 80, charging: false, temperature: 32 }
        const g = (over) => L.idleGlance(Object.assign({}, base, over))

        compare(g({ event: soon }).kind, "event")
        compare(g({ event: soon }).detail, "in 25 min")
        compare(g({ event: Object.assign({}, soon, { start: new Date(2026, 9, 23, 16, 30) }) }).detail, "now")
        // Too far away, all-day, or switched off: fall through.
        compare(g({ event: Object.assign({}, soon, { start: new Date(2026, 9, 23, 17, 6) }) }).kind, "clock")
        compare(g({ event: Object.assign({}, soon, { allDay: true }) }).kind, "clock")
        compare(g({ event: soon, show: Object.assign({}, all, { events: false }) }).kind, "clock")

        compare(g({ battery: 12 }).kind, "batteryLow")
        compare(g({ battery: 12, charging: true }).kind, "clock")
        compare(g({ event: soon, battery: 12 }).kind, "event")

        const clock = g({})
        compare(clock.time, "16:35")
        compare(clock.showTime, true)
        compare(clock.showWeather, true)
        compare(clock.showBattery, true)
        compare(g({ temperature: NaN }).showWeather, false)
        compare(g({ battery: -1 }).showBattery, false)
        compare(g({ show: { events: true, battery: true, time: false, weather: false } }).kind, "clock")
        compare(g({ show: { events: true, battery: false, time: false, weather: false } }).kind, "none")    }

    function test_device_label() {
        compare(L.deviceLabel("Ryzen HD Audio Controller Speaker", "Speaker"), "Speaker")
        compare(L.deviceLabel("Galaxy Buds2", "Headset"), "Galaxy Buds2")
        compare(L.deviceLabel("USB Mic", ""), "USB Mic")
    }

    function test_ago() {
        const now = new Date(2026, 9, 23, 16, 52).getTime()
        compare(L.ago(now - 20000, now), "now")
        compare(L.ago(now - 9 * 60000, now), "9 min")
        compare(L.ago(now - 2 * 3600000, now), "2 h")
        compare(L.ago(new Date(2026, 9, 22, 23, 0).getTime(), now), "Yesterday")
        compare(L.ago(new Date(2026, 9, 20, 9, 0).getTime(), now), "20 Oct")
    }

    function test_note_when() {
        const now = new Date(2026, 9, 23, 16, 52).getTime()
        compare(L.noteWhen(new Date(2026, 9, 23, 9, 5).getTime(), now), "Today 09:05")
        compare(L.noteWhen(new Date(2026, 9, 22, 9, 5).getTime(), now), "Yesterday")
        compare(L.noteWhen(new Date(2026, 9, 20, 9, 5).getTime(), now), "20 Oct")
    }

    function test_clip_meta() {
        const now = 10000000
        compare(L.clipMeta({ kind: "text", text: "hello", time: now }, now), "Text · 5 characters · just now")
        compare(L.clipMeta({ kind: "link", text: "https://x.y", time: now - 9 * 60000 }, now), "Link · 9 min ago")
        compare(L.clipMeta({ kind: "image", width: 1920, height: 1080, time: now - 3600000 }, now), "Image · 1920 × 1080 · 1 h ago")
    }

    function test_clip_rows() {
        const items = [
            { id: "1", kind: "text", text: "Hello there", pinned: false },
            { id: "2", kind: "link", text: "https://a.b", pinned: true },
            { id: "3", kind: "image", pinned: false }
        ]
        compare(L.clipRows(items, "", "all").map(r => r.header || r.id), ["Pinned", "2", "Recent", "1", "3"])
        compare(L.clipRows(items, "", "image").map(r => r.header || r.id), ["Recent", "3"])
        compare(L.clipRows(items, "HELLO", "all").map(r => r.header || r.id), ["Recent", "1"])
        compare(L.clipRows([], "", "all").length, 0)
    }

    function test_job_merge() {
        const a = L.jobMerge({}, { title: "Downloading", percent: 140 }, 1000)
        compare(a.startMs, 1000)
        compare(a.percent, 100)
        const b = L.jobMerge(a, { speed: 5 }, 3000)
        compare(b.title, "Downloading")
        compare(b.startMs, 1000)
        compare(b.speed, 5)
        compare(a.speed, undefined)
    }

    function test_job_name() {
        compare(L.jobName({ descriptionValue2: "/home/alnyz/Downloads/ubuntu-26.04.1-desktop-amd64.iso" }), "ubuntu-26.04.1-desktop-amd64.iso")
        compare(L.jobName({ descriptionValue1: "https://x.org/a/b.zip?t=1" }), "b.zip")
        compare(L.jobName({ title: "Copying" }), "Copying")
        compare(L.jobName({}), "File")
    }

    function test_job_verb() {
        compare(L.jobVerb({ title: "Copying", destUrl: "file:///run/media/alnyz/Backup" }), "Copying to Backup")
        compare(L.jobVerb({ title: "Extracting Files" }), "Extracting Files")
    }

    function test_job_time_left() {
        compare(L.jobTimeLeft({ totalBytes: 100e6, processedBytes: 64e6, speed: 1e6 }), "36 s")
        compare(L.jobTimeLeft({ totalBytes: 100e6, processedBytes: 64e6, speed: 0 }), "")
        compare(L.jobTimeLeft({ processedBytes: 64e6, speed: 1e6 }), "")
        compare(L.jobTimeLeft({ totalBytes: 6.5e9, processedBytes: 0, speed: 11e6 }), "10 min")
        compare(L.jobTimeLeft({ totalBytes: 4e9, processedBytes: 0, speed: 1e6 }), "1 h 7 min")
    }

    function test_jobs_summary() {
        const a = { startMs: 0, totalBytes: 6.5e9, processedBytes: 2.7e9, percent: 42 }
        const b = { startMs: 0, totalBytes: 14.2e9, processedBytes: 9.1e9, percent: 64 }
        const young = { startMs: 9000, percent: 10 }
        const one = L.jobsSummary({ x: a, y: young }, 10000)
        compare(one.count, 1)
        compare(one.shown[0], a)
        compare(L.jobsSummary({ x: a, y: b }, 10000).percent, 57)
        compare(L.jobsSummary({ x: a, y: { startMs: 0, percent: 50 } }, 10000).percent, 46)
        const none = L.jobsSummary({}, 10000)
        compare(none.count, 0)
        compare(none.percent, 0)
        compare(none.shown, [])
    }

    function test_job_titles() {
        compare(L.jobDoneTitle({ title: "Downloading" }), "Downloaded")
        compare(L.jobDoneTitle({ title: "Copying" }), "Copied")
        compare(L.jobDoneTitle({ title: "Moving" }), "Moved")
        compare(L.jobDoneTitle({ title: "Extracting Files" }), "Extracted")
        compare(L.jobDoneTitle({ title: "Deleting" }), "Deleting")
        compare(L.jobFailTitle({ title: "Downloading" }), "Download failed")
        compare(L.jobFailTitle({ title: "Copying" }), "Copy failed")
        compare(L.jobFailTitle({ title: "Moving" }), "Move failed")
        compare(L.jobFailTitle({ title: "Extracting Files" }), "Extraction failed")
        compare(L.jobFailTitle({ title: "Deleting" }), "Deleting failed")
    }

    function test_format_gb() {
        compare(L.formatGB(2.7e9), "2.7")
        compare(L.formatGB(14.2e9), "14.2")
    }
}
