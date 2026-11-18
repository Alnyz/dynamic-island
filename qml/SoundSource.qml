import QtQuick
import org.kde.plasma.private.volume
import "logic.js" as L

// Speakers, microphones and app streams from Plasma's own volume module.
QtObject {
    id: sound

    // Only listen to the mic while the mixer is on screen.
    property bool monitorMic: false
    property var outputs: []
    property var inputs: []
    property var apps: []
    // Apps recording from a microphone right now.
    property var recorders: []
    readonly property var defaultInput: inputs.find(d => d.default) || null
    readonly property var defaultOutput: outputs.find(d => d.default) || null
    readonly property real micLevel: monitorMic && monitor.available ? monitor.volume : -1
    // The speakers' level for the pill's bars, measured only while they're shown.
    property bool monitorOutput: false
    // A monitor stream that dies keeps its last value for ever, so the bars would sit still
    // until it's made again (a pause and play did that by turning monitoring off and on).
    // A level that doesn't move is treated as dead: the bars fall back to their loop while
    // the stream is made again.
    property bool outputStalled: false
    readonly property real outputLevel: monitorOutput && !outputStalled && outputMonitor.available ? outputMonitor.volume : -1
    property real lastLevel: -1
    property int stillTicks: 0
    property int cooldownTicks: 0

    // Level checks run once a second while the bars are up.
    function checkOutput() {
        if (!monitorOutput || cooldownTicks > 0) {
            if (cooldownTicks > 0)
                --cooldownTicks
            return
        }
        if (!outputMonitor.available) {
            outputStalled = true
            restartOutput()
            return
        }
        const v = outputMonitor.volume
        if (v !== lastLevel) {
            lastLevel = v
            stillTicks = 0
            outputStalled = false
            return
        }
        // Silence can last, so it's given longer before the stream is counted as dead.
        const quiet = v <= 0.0001
        if (++stillTicks >= (quiet ? 10 : 3)) {
            if (!quiet)
                outputStalled = true
            restartOutput()
        }
    }

    function restartOutput() {
        outputMonitor.target = null
        stillTicks = 0
        lastLevel = -1
        // The new stream needs a moment before its first level arrives.
        cooldownTicks = 5
        Qt.callLater(sound.updateOutputTarget)
    }

    function updateOutputTarget() {
        const t = sound.monitorOutput ? sound.defaultOutput : null
        if (outputMonitor.target !== t)
            outputMonitor.target = t
    }

    function collect(list) {
        const out = []
        for (let i = 0; i < list.count; ++i)
            out.push(list.objectAt(i).p)
        return out
    }
    function rebuild() {
        outputs = collect(sinkList).filter(d => !d.virtualDevice)
        inputs = collect(sourceList).filter(d => !d.virtualDevice && !d.name.endsWith(".monitor"))
        apps = collect(appList).filter(a => !a.virtualStream)
        recorders = L.recordingApps(collect(recordList))
        Qt.callLater(sound.updateOutputTarget)
    }

    property Instantiator sinkList: Instantiator {
        model: SinkModel {}
        delegate: QtObject { required property var model; readonly property var p: model.PulseObject }
        onObjectAdded: Qt.callLater(sound.rebuild)
        onObjectRemoved: Qt.callLater(sound.rebuild)
    }
    property Instantiator sourceList: Instantiator {
        model: SourceModel {}
        delegate: QtObject { required property var model; readonly property var p: model.PulseObject }
        onObjectAdded: Qt.callLater(sound.rebuild)
        onObjectRemoved: Qt.callLater(sound.rebuild)
    }
    property Instantiator appList: Instantiator {
        model: SinkInputModel {}
        delegate: QtObject { required property var model; readonly property var p: model.PulseObject }
        onObjectAdded: Qt.callLater(sound.rebuild)
        onObjectRemoved: Qt.callLater(sound.rebuild)
    }

    property Instantiator recordList: Instantiator {
        model: SourceOutputModel {}
        delegate: QtObject { required property var model; readonly property var p: model.PulseObject }
        onObjectAdded: Qt.callLater(sound.rebuild)
        onObjectRemoved: Qt.callLater(sound.rebuild)
    }

    property VolumeMonitor monitor: VolumeMonitor {
        target: sound.monitorMic ? sound.defaultInput : null
    }
    // Set by updateOutputTarget(), so it can be made again when it goes quiet.
    property VolumeMonitor outputMonitor: VolumeMonitor { id: outputMonitor }

    property Timer outputWatchdog: Timer {
        interval: 1000
        repeat: true
        running: sound.monitorOutput
        onTriggered: sound.checkOutput()
    }

    onMonitorOutputChanged: {
        if (!monitorOutput) {
            outputStalled = false
            stillTicks = 0
            cooldownTicks = 0
            lastLevel = -1
        }
        Qt.callLater(sound.updateOutputTarget)
    }
    onDefaultOutputChanged: Qt.callLater(sound.updateOutputTarget)
    Component.onCompleted: Qt.callLater(sound.updateOutputTarget)
}
