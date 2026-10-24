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
}
