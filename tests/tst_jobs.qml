import QtQuick
import QtTest
import "../qml"

TestCase {
    id: tc
    name: "Jobs"

    property real t: 0

    Component {
        id: jobsComp
        JobsModel { now: () => tc.t }
    }

    SignalSpy { id: finishedSpy; signalName: "finished" }
    SignalSpy { id: failedSpy; signalName: "failed" }

    function make() {
        const m = createTemporaryObject(jobsComp, tc)
        finishedSpy.clear()
        failedSpy.clear()
        finishedSpy.target = m
        failedSpy.target = m
        return m
    }

    function init() { t = 0 }

    function test_short_job_is_silent() {
        const m = make()
        m.update(":1.131 /jobs/1", { title: "Copying", percent: 50 })
        t = 1500
        m.tick()
        compare(m.summary.count, 0)
        m.end(":1.131 /jobs/1", 0, "")
        compare(finishedSpy.count, 0)
        compare(failedSpy.count, 0)
    }

    function test_finished_job() {
        const m = make()
        m.update(":1.65 /jobs/1", { title: "Downloading", descriptionValue2: "/home/alnyz/Downloads/a.iso", percent: 40 })
        t = 3000
        m.tick()
        compare(m.summary.count, 1)
        m.end(":1.65 /jobs/1", 0, "")
        compare(finishedSpy.count, 1)
        const job = finishedSpy.signalArguments[0][0]
        compare(job.name, "a.iso")
        compare(job.title, "Downloading")
        compare(job.folder, "file:///home/alnyz/Downloads")
        compare(m.summary.count, 0)
    }

    function test_failed_job() {
        const m = make()
        m.update(":1.131 /jobs/2", { title: "Copying", descriptionValue2: "/run/media/alnyz/Backup/Photos 2026" })
        t = 3000
        m.end(":1.131 /jobs/2", 1, "Not enough free space")
        compare(finishedSpy.count, 0)
        compare(failedSpy.count, 1)
        compare(failedSpy.signalArguments[0][0].name, "Photos 2026")
        compare(failedSpy.signalArguments[0][1], "Not enough free space")
    }

    function test_vanished_job_is_dropped() {
        const m = make()
        m.update(":1.131 /jobs/1", { title: "Copying" })
        m.update(":1.131 /jobs/2", { title: "Copying" })
        m.update(":1.65 /jobs/1", { title: "Downloading" })
        t = 3000
        m.dropSender(":1.131")
        m.tick()
        compare(m.summary.count, 1)
        compare(finishedSpy.count, 0)
        compare(failedSpy.count, 0)
    }

    function test_clear() {
        const m = make()
        m.update(":1.65 /jobs/1", { title: "Downloading" })
        t = 3000
        m.clear()
        m.tick()
        compare(m.summary.count, 0)
    }
}
