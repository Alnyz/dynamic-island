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
        compare(L.islandState(true, true, false, true, true), "menu")
        compare(L.islandState(true, true, true, false, true), "open")
        compare(L.islandState(true, true, false, true, true, true), "tour")
    }

    function test_alert_size() {
        compare(L.alertSize("volume", 32, 12), { w: 300, h: 32, r: 12 })
        compare(L.alertSize("notification", 32, 12), { w: 400, h: 64, r: 22 })
        compare(L.alertSize("notification", 32, 12, { buttons: [{ key: "a", label: "A" }] }), { w: 400, h: 100, r: 24 })
        compare(L.alertSize("notification", 32, 12, { buttons: [] }), { w: 400, h: 64, r: 22 })
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

        // A Bluetooth device running low comes after the laptop's battery, before tasks.
        const buds = [{ name: "Noise Earbuds", battery: 12, icon: "audio-headset" }]
        compare(g({ devices: buds }).kind, "deviceLow")
        compare(g({ devices: buds }).title, "Noise Earbuds")
        compare(g({ devices: buds }).detail, "12%")
        compare(g({ devices: buds, battery: 12 }).kind, "batteryLow")
        compare(g({ devices: buds, todo: { id: "t", text: "x" } }).kind, "deviceLow")
        compare(g({ devices: [{ name: "Mouse", battery: 40 }] }).kind, "clock")

        // The next task comes after events and low battery, before the clock.
        const task = { id: "t1", text: "Send invoice", done: false }
        compare(g({ todo: task }).kind, "todo")
        compare(g({ todo: task }).title, "Send invoice")
        compare(g({ todo: task }).id, "t1")
        compare(g({ todo: task, event: soon }).kind, "event")
        compare(g({ todo: task, battery: 12 }).kind, "batteryLow")
        compare(g({ todo: task, show: Object.assign({}, all, { todo: false }) }).kind, "clock")
        compare(g({ todo: null }).kind, "clock")

        const clock = g({})
        compare(clock.time, "16:35")
        compare(clock.showTime, true)
        compare(clock.showWeather, true)
        compare(clock.showBattery, true)
        compare(g({ temperature: NaN }).showWeather, false)
        compare(g({ battery: -1 }).showBattery, false)
        compare(clock.updates, 0)
        compare(g({ updates: 7 }).updates, 0)
        compare(g({ updates: 7, show: Object.assign({}, all, { updates: true }) }).updates, 7)
        compare(g({ updates: -1, show: Object.assign({}, all, { updates: true }) }).updates, 0)
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
        compare(L.jobName({ title: "Extracting Files", descriptionValue1: "/home/alnyz/test-extract-3gb.zip", descriptionValue2: "/home/alnyz" }), "test-extract-3gb.zip")
        compare(L.jobName({ descriptionValue2: "/home/alnyz/Downloads/50% off.pdf" }), "50% off.pdf")
        compare(L.jobName({ descriptionValue2: "/home/alnyz/Music/Track #1.flac" }), "Track #1.flac")
        compare(L.jobName({ descriptionValue1: "https://x.org/a%20b.zip#top" }), "a b.zip")
        compare(L.jobName({ descriptionValue1: "https://x.org/100%.zip" }), "100%.zip")
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

    function test_format_size() {
        compare(L.formatSize(2.7e9), "2.7 GB")
        compare(L.formatSize(14.2e9), "14.2 GB")
        compare(L.formatSize(40.4e6), "40 MB")
        compare(L.formatSize(300e3), "300 KB")
        compare(L.formatSize(0), "0 KB")
    }

    readonly property var notif: o => Object.assign({ app: "Telegram", desktopEntry: "org.telegram.desktop", icon: "telegram", title: "Rina", body: "hi", replaces: 0 }, o)
    readonly property var allOn: ({ save: true, system: true, apps: true, others: true, off: [] })

    function test_notif_kind() {
        compare(L.notifKind(notif()), "apps")
        compare(L.notifKind(notif({ desktopEntry: "org.kde.kdeconnect.daemon" })), "system")
        compare(L.notifKind(notif({ desktopEntry: "" })), "others")
    }

    function test_notif_key() {
        compare(L.notifKey(notif()), "org.telegram.desktop")
        compare(L.notifKey(notif({ desktopEntry: "", app: "foo" })), "app:foo")
        verify(L.notifKey(notif({ desktopEntry: "", app: "foo" })) !== L.notifKey(notif({ desktopEntry: "", app: "bar" })))
    }

    function test_history_allowed() {
        verify(L.historyAllowed(notif(), allOn))
        verify(!L.historyAllowed(notif(), Object.assign({}, allOn, { save: false })))
        verify(!L.historyAllowed(notif(), Object.assign({}, allOn, { apps: false })))
        verify(!L.historyAllowed(notif(), Object.assign({}, allOn, { off: ["org.telegram.desktop"] })))
        verify(!L.historyAllowed(notif({ desktopEntry: "" }), Object.assign({}, allOn, { others: false })))
    }

    function test_history_add() {
        const one = L.historyAdd([], notif(), 1000, 7)
        compare(one.length, 1)
        compare(one[0].key, "org.telegram.desktop")
        compare(one[0].time, 1000)
        compare(one[0].seen, false)
        const two = L.historyAdd(one, notif({ title: "Budi" }), 2000, 7)
        compare(two.length, 2)
        compare(two[0].title, "Budi")
    }

    function test_history_ids_unique_at_cap() {
        let items = []
        for (let i = 0; i < L.HISTORY_MAX; i++)
            items.push({ id: "old-" + i, key: "k", time: 1000, seen: false })
        items = L.historyAdd(items, notif({ title: "a" }), 2000, 7)
        items = L.historyAdd(items, notif({ title: "b" }), 2000, 7)
        verify(items[0].id !== items[1].id)
    }

    function test_history_add_replace() {
        let items = L.historyAdd([], notif({ body: "a" }), 1000, 7)
        items = L.historyAdd(items, notif({ body: "b" }), 2000, 7)
        items = L.historyAdd(items, notif({ replaces: 5, body: "edited" }), 3000, 7)
        compare(items.length, 2)
        compare(items[0].body, "edited")
        compare(items[0].time, 3000)
        compare(items[1].body, "a")
        const fresh = L.historyAdd([], notif({ replaces: 5 }), 1000, 7)
        compare(fresh.length, 1)
    }

    function test_history_prune() {
        const day = 86400000
        const now = 100 * day
        const rows = [{ id: "a", time: now - 6 * day }, { id: "b", time: now - 8 * day }]
        compare(L.historyPrune(rows, now, 7).map(r => r.id), ["a"])
        const many = []
        for (let i = 0; i < 205; i++)
            many.push({ id: "r" + i, time: now - i })
        const kept = L.historyPrune(many, now, 7)
        compare(kept.length, 200)
        compare(kept[0].id, "r0")
    }

    function test_new_count() {
        const rows = [{ time: 4000, seen: false }, { time: 3000, seen: true }, { time: 1000, seen: false }]
        compare(L.newCount(rows, 2000), 1)
        verify(L.isNewItem(rows[0], 2000))
        verify(!L.isNewItem(rows[1], 2000))
    }

    function test_history_groups() {
        let items = L.historyAdd([], notif(), 1000, 7)
        items = L.historyAdd(items, notif({ app: "Discord", desktopEntry: "discord" }), 2000, 7)
        items = L.historyAdd(items, notif(), 3000, 7)
        const groups = L.historyGroups(items)
        compare(groups.map(g => g.app), ["Telegram", "Discord"])
        compare(groups[0].rows.map(r => r.time), [3000, 1000])
        compare(groups[0].icon, "telegram")
    }

    function test_time_ago() {
        const now = new Date(2026, 9, 25, 15, 42).getTime()
        compare(L.ago(now - 30000, now), "now")
        compare(L.ago(now - 3 * 60000, now), "3 min")
        compare(L.ago(now - 2 * 3600000, now), "2 h")
        compare(L.ago(new Date(2026, 9, 24, 23, 0).getTime(), now), "Yesterday")
        compare(L.ago(new Date(2026, 9, 23, 9, 0).getTime(), now), "23 Oct")
    }

    function test_parse_known_apps() {
        compare(L.parseKnownApps("not json"), [])
        compare(L.parseKnownApps('[{"key":"discord","name":"Discord"},{"name":"no key"}]').length, 1)
    }

    function test_remember_app() {
        const apps = L.rememberApp([], notif())
        compare(apps, [{ key: "org.telegram.desktop", name: "Telegram", icon: "telegram", kind: "apps" }])
        compare(L.rememberApp(apps, notif()).length, 1)
        verify(L.rememberApp(apps, notif({ desktopEntry: "" })) === apps)
    }

    function test_full_screen_allowed() {
        const f = { levels: true, jobs: true, privacy: false, devices: true, power: false, allNotifications: false, urgent: ["org.telegram.desktop", "app:Steam"] }
        verify(L.fullScreenAllowed({ kind: "volume" }, f))
        verify(L.fullScreenAllowed({ kind: "brightness" }, f))
        verify(L.fullScreenAllowed({ kind: "capslock" }, f))
        verify(!L.fullScreenAllowed({ kind: "privacy" }, f))
        verify(!L.fullScreenAllowed({ kind: "power" }, f))
        verify(L.fullScreenAllowed({ kind: "color" }, f))
        verify(L.fullScreenAllowed({ kind: "notification", desktopEntry: "org.telegram.desktop", app: "Telegram", urgency: 1 }, f))
        verify(L.fullScreenAllowed({ kind: "notification", desktopEntry: "", app: "Steam", urgency: 1 }, f))
        verify(!L.fullScreenAllowed({ kind: "notification", desktopEntry: "discord", app: "Discord", urgency: 1 }, f))
        verify(L.fullScreenAllowed({ kind: "notification", desktopEntry: "discord", app: "Discord", urgency: 2 }, f))
        verify(L.fullScreenAllowed({ kind: "notification", desktopEntry: "discord", app: "Discord" }, Object.assign({}, f, { allNotifications: true })))
    }

    function test_new_apps() {
        compare(L.newApps([], ["Zoom"]), ["Zoom"])
        compare(L.newApps(["Zoom"], ["Zoom", "OBS"]), ["OBS"])
        compare(L.newApps(["Zoom", "OBS"], ["Zoom"]), [])
        compare(L.newApps(["Zoom"], ["Zoom"]), [])
    }

    function test_privacy_alert_size() {
        compare(L.alertSize("privacy", 32, 12), { w: 330, h: 32, r: 12 })
    }

    // WCAG contrast ratio, for checking the theme stays readable.
    function contrast(a, b) {
        const lum = c => {
            const ch = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
            const q = Qt.color(c)
            return 0.2126 * ch(q.r) + 0.7152 * ch(q.g) + 0.0722 * ch(q.b)
        }
        const x = lum(a), y = lum(b)
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
    }

    function test_theme_colors() {
        const roles = ["window", "windowText", "text", "placeholderText", "mid", "base", "alternateBase", "button", "dark", "brightText"]
        for (const light of [false, true]) {
            const t = L.themeColors(light)
            for (const r of roles)
                verify(t[r] !== undefined, r)
            // Body text and secondary text stay readable on the background and on panels.
            for (const bg of [t.window, t.base, t.alternateBase]) {
                verify(contrast(t.windowText, bg) >= 7, "windowText on " + bg)
                verify(contrast(t.text, bg) >= 7, "text on " + bg)
                verify(contrast(t.placeholderText, bg) >= 3.5, "placeholderText on " + bg + " (light " + light + ")")
                verify(contrast(t.brightText, bg) >= 4.5, "brightText on " + bg)
            }
        }
        // The dark theme keeps the island's original look.
        compare(L.themeColors(false).window, "#000000")
        compare(L.themeColors(false).brightText, "#e8e2d0")
    }

    function test_island_opacity() {
        compare(L.islandOpacity(-1, false), 100)
        compare(L.islandOpacity(-1, true), 78)
        compare(L.islandOpacity(55, true), 55)
        compare(L.islandOpacity(55, false), 55)
        compare(L.islandOpacity(5, false), 20)
        compare(L.islandOpacity(300, false), 100)
    }

    function test_custom_colours_stay_readable() {
        // A spread of hues and lightnesses, including awkward mid-tones.
        const samples = ["#000000", "#ffffff", "#808080", "#767676", "#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff375f",
                         "#0b1f33", "#1e1033", "#fff4dc", "#30d158", "#5e5ce6", "#ff9f0a", "#3a3a3c", "#c7c7cc", "#008080"]
        for (const c of samples) {
            const t = L.themeColors(false, c)
            verify(L.contrastRatio(t.windowText, t.window) >= 4.5, "windowText on " + c)
            verify(L.contrastRatio(t.windowText, t.base) >= 4.5, "windowText on base of " + c)
            verify(L.contrastRatio(t.text, t.window) >= 3.5, "text on " + c)
            verify(L.contrastRatio(t.placeholderText, t.window) >= 2.5, "placeholderText on " + c)
            compare(Qt.color(t.window), Qt.color(c))
        }
        compare(L.wantsDarkText("#fff4dc"), true)
        compare(L.wantsDarkText("#0b1f33"), false)
    }

    function test_bar_height() {
        for (let i = 0; i < 4; ++i) {
            compare(L.barHeight(0, i, 0), 3)
            verify(L.barHeight(1, i, 0) <= 14)
            verify(L.barHeight(1, i, 0) > 8)
            // Out-of-range levels are clamped.
            compare(L.barHeight(-1, i, 0), 3)
            compare(L.barHeight(5, i, 1), L.barHeight(1, i, 1))
        }
        // Louder is taller; bars differ from each other.
        verify(L.barHeight(0.8, 1, 0) > L.barHeight(0.2, 1, 0))
        verify(L.barHeight(0.8, 0, 0) !== L.barHeight(0.8, 3, 0))
        // The sway moves a bar over time.
        verify(L.barHeight(0.8, 2, 0) !== L.barHeight(0.8, 2, 1.5))
    }

    function test_parse_lrc() {
        const lines = L.parseLrc("[ar:CG5]\n[00:12.50]Second\n[00:03.2]First\n\n[01:00.00][02:00.00]Chorus\nno time here\n[00:20.123]")
        compare(lines.length, 5)
        compare(lines[0], { ms: 3200, text: "First" })
        compare(lines[1], { ms: 12500, text: "Second" })
        compare(lines[2], { ms: 20123, text: "" })
        compare(lines[3], { ms: 60000, text: "Chorus" })
        compare(lines[4], { ms: 120000, text: "Chorus" })
        compare(L.parseLrc("").length, 0)
        compare(L.parseLrc(null).length, 0)
    }

    function test_lyric_line() {
        const lines = [{ ms: 1000 }, { ms: 5000 }, { ms: 9000 }]
        compare(L.lyricLine(lines, 0), -1)
        compare(L.lyricLine(lines, 1000), 0)
        compare(L.lyricLine(lines, 4999), 0)
        compare(L.lyricLine(lines, 5000), 1)
        compare(L.lyricLine(lines, 99999), 2)
        compare(L.lyricLine([], 5000), -1)
    }

    function test_lyrics_urls() {
        compare(L.lyricsGetUrl("Maroon 5", "Girls Like You", "Red Pill Blues", 235400000),
                "https://lrclib.net/api/get?artist_name=Maroon%205&track_name=Girls%20Like%20You&album_name=Red%20Pill%20Blues&duration=235")
        compare(L.lyricsGetUrl("CG5", "Dancin'", "", 0), "https://lrclib.net/api/get?artist_name=CG5&track_name=Dancin'")
        compare(L.lyricsSearchUrl("CG5", "Dancin (Official Video)"), "https://lrclib.net/api/search?artist_name=CG5&track_name=Dancin")
    }

    function test_pick_lyrics() {
        const synced = { artistName: "CG5", trackName: "Dancin’", duration: 198, syncedLyrics: "[00:01.00]x", plainLyrics: "x" }
        const plain = { artistName: "CG5", trackName: "Dancin'", duration: 196, syncedLyrics: null, plainLyrics: "x" }
        const far = { artistName: "CG5", trackName: "Dancin", duration: 260, syncedLyrics: "[00:01.00]x" }
        const other = { artistName: "Somebody", trackName: "Dancin", duration: 198, syncedLyrics: "[00:01.00]x" }
        const empty = { artistName: "CG5", trackName: "Dancin", duration: 198 }
        compare(L.pickLyrics([plain, synced], "CG5", "Dancin'", 197000000), synced)
        compare(L.pickLyrics([plain, far], "CG5", "Dancin'", 197000000), plain)
        compare(L.pickLyrics([far, other, empty], "CG5", "Dancin'", 197000000), null)
        // Unknown length: duration isn't checked.
        compare(L.pickLyrics([far], "CG5", "Dancin'", 0), far)
        compare(L.pickLyrics(undefined, "CG5", "Dancin'", 0), null)
    }

    function test_distinct_players() {
        const multiplexer = { objectName: "brave.instance1", identity: "Brave", tag: "mux" }
        const brave = { objectName: "brave.instance1", identity: "Brave", tag: "real" }
        const ctld = { objectName: "playerctld", identity: "Brave" }
        const spotify = { objectName: "spotify", identity: "Spotify" }
        const list = L.distinctPlayers([multiplexer, brave, ctld, spotify])
        compare(list.length, 2)
        compare(list[0].tag, "real")
        compare(list[1].identity, "Spotify")
        compare(L.distinctPlayers([]).length, 0)
        compare(L.distinctPlayers(undefined).length, 0)
    }

    function test_pomodoro_message() {
        compare(L.pomodoroMessage("work", "break", 5), { title: "Time for a break", body: "5 minutes" })
        compare(L.pomodoroMessage("work", "longBreak", 15), { title: "Time for a break", body: "A long break: 15 minutes" })
        compare(L.pomodoroMessage("break", "work", 25), { title: "Back to focus", body: "25 minutes of focus" })
    }

    function test_bluetooth_summary() {
        compare(L.bluetoothSummary([]), { badge: "", label: "Bluetooth" })
        compare(L.bluetoothSummary(undefined), { badge: "", label: "Bluetooth" })
        compare(L.bluetoothSummary([{ name: "Mouse", battery: -1 }]), { badge: "", label: "Bluetooth · Mouse" })
        compare(L.bluetoothSummary([{ name: "Earbuds", battery: 80 }, { name: "Mouse", battery: 35 }]),
                { badge: "35", label: "Bluetooth · Earbuds 80%, Mouse 35%" })
        compare(L.lowDevice([{ name: "A", battery: 14 }, { name: "B", battery: 9 }, { name: "C", battery: -1 }]).name, "B")
        compare(L.lowDevice([{ name: "A", battery: 50 }]), null)
    }

    function test_pill_menu() {
        const plain = L.pillMenu({ dnd: false, hidden: false }).map(r => r.key)
        compare(plain, ["dnd-hour", "timers", "hide-hour", "settings"])
        const flipped = L.pillMenu({ dnd: true, hidden: true }).map(r => r.key)
        compare(flipped, ["dnd-off", "timers", "show", "settings"])
        compare(L.pillMenu({}).find(r => r.key === "timers").minutes, [5, 10, 25])
    }

    function test_volume_after_steps() {
        compare(L.volumeAfterSteps(32768, 1, 65536), 36045)
        compare(L.volumeAfterSteps(32768, -2, 65536), 26214)
        compare(L.volumeAfterSteps(64000, 3, 65536), 65536)
        compare(L.volumeAfterSteps(1000, -1, 65536), 0)
    }

    function test_timer_step_minutes() {
        compare(L.timerStepMinutes(300000, 2), 2)
        compare(L.timerStepMinutes(300000, -1), -1)
        // 5 min left: at most 4 can come off, leaving 1.
        compare(L.timerStepMinutes(300000, -9), -4)
        compare(L.timerStepMinutes(90000, -1), 0)
        compare(L.timerStepMinutes(30000, -1), 0)
    }

    function test_held_art() {
        // A cover is taken as soon as it comes.
        let h = L.heldArt(null, { key: "a", url: "file:///a.jpg" })
        compare(h.url, "file:///a.jpg")
        // The browser takes it away mid-song: keep it.
        h = L.heldArt(h, { key: "a", url: "" })
        compare(h.url, "file:///a.jpg")
        // Skipped to a song with no cover yet: don't show the old one.
        h = L.heldArt(h, { key: "b", url: "" })
        compare(h.url, "")
        // Its cover arrives later.
        h = L.heldArt(h, { key: "b", url: "file:///b.jpg" })
        compare(h.url, "file:///b.jpg")
    }

    function test_cover_search_url() {
        compare(L.coverSearchUrl("CG5", "Dancin’ (Official Video)"),
                "https://itunes.apple.com/search?media=music&entity=song&limit=10&term=CG5%20Dancin%E2%80%99")
    }

    function test_pick_cover() {
        const art = "https://x/Cover.jpg/100x100bb.jpg"
        const big = "https://x/Cover.jpg/600x600bb.jpg"
        // Curly and straight apostrophes match; the 600 px version is used.
        compare(L.pickCover([{ artistName: "CG5", trackName: "Dancin'", artworkUrl100: art }], "CG5", "Dancin’"), big)
        // Remix and edit tags are ignored on both sides.
        compare(L.pickCover([{ artistName: "OMI", trackName: "Cheerleader (Felix Jaehn Remix) [Radio Edit]", artworkUrl100: art }],
                            "OMI", "Cheerleader (Felix Jaehn Remix) (Radio Edit)"), big)
        // A featured artist on iTunes still matches.
        compare(L.pickCover([{ artistName: "Maroon 5 & Cardi B", trackName: "Girls Like You", artworkUrl100: art }], "Maroon 5", "Girls Like You"), big)
        // The first result that matches wins over earlier ones that don't.
        compare(L.pickCover([{ artistName: "CG5", trackName: "Other Song", artworkUrl100: "https://x/o/100x100bb.jpg" },
                             { artistName: "CG5", trackName: "Dancin'", artworkUrl100: art }], "CG5", "Dancin'"), big)
        // Same artist, different song, or different artist: no cover rather than a wrong one.
        compare(L.pickCover([{ artistName: "CG5", trackName: "Other Song", artworkUrl100: art }], "CG5", "Dancin'"), "")
        compare(L.pickCover([{ artistName: "Somebody", trackName: "Dancin'", artworkUrl100: art }], "CG5", "Dancin'"), "")
        compare(L.pickCover([], "CG5", "Dancin'"), "")
        compare(L.pickCover(undefined, "CG5", "Dancin'"), "")
        compare(L.pickCover([{ artistName: "CG5", trackName: "Dancin'", artworkUrl100: art }], "", "Dancin'"), "")
    }
}
