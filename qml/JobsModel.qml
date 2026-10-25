import QtQuick
import "logic.js" as L

QtObject {
    id: model

    property var now: () => Date.now()
    // Keyed by sender + object path; reassigned on every change so bindings follow.
    property var jobs: ({})
    property int tickCount: 0
    readonly property var summary: {
        tickCount
        return L.jobsSummary(jobs, now())
    }
    signal finished(var job)
    signal failed(var job, string error)

    function tick() { tickCount++ }

    function update(key, props) {
        const next = Object.assign({}, jobs)
        next[key] = L.jobMerge(jobs[key] || {}, props, now())
        jobs = next
    }

    function end(key, code, error) {
        const job = jobs[key]
        if (!job)
            return
        remove(k => k === key)
        // Code 1 is KDE's "killed": the user cancelled it, so no alert.
        if (now() - job.startMs < 2000 || code === 1)
            return
        const out = { name: L.jobName(job), title: job.title || "", folder: folderOf(job) }
        if (code === 0)
            finished(out)
        else
            failed(out, error)
    }

    function dropSender(sender) { remove(k => k.startsWith(sender + " ")) }
    function clear() { jobs = {} }

    function remove(match) {
        const next = {}
        for (const k in jobs)
            if (!match(k))
                next[k] = jobs[k]
        jobs = next
    }

    // destUrl is the target folder when the app sends it; otherwise the folder holding descriptionValue2,
    // which for an extraction is the destination folder itself.
    function folderOf(job) {
        if (job.destUrl)
            return job.destUrl
        let path = String(job.descriptionValue2 || "")
        if (!path.startsWith("/"))
            return ""
        if (job.title !== "Extracting Files")
            path = path.substring(0, path.lastIndexOf("/"))
        return "file://" + path.split("/").map(encodeURIComponent).join("/")
    }

    property Timer ticker: Timer {
        interval: 1000
        repeat: true
        running: Object.keys(model.jobs).length > 0
        onTriggered: model.tick()
    }
}
