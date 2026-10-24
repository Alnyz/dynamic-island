import QtQuick
import QtTest
import "../qml"

Item {
    id: stage
    width: 860
    height: 360

    readonly property real full: 65536
    // Fakes are copied when passed between var properties, so changes are recorded here by name.
    property var changes: ({})

    function device(desc, port, isDefault) {
        return { description: desc, ports: [{ description: port }], activePortIndex: 0, default: isDefault,
                 volume: 0.5 * full, muted: false, iconName: "audio-speakers", name: desc }
    }
    function app(name, volume) {
        return { name: name + " track", client: { name: name }, properties: { "application.icon_name": "" },
                 volume: volume * full, muted: false, corked: false, virtualStream: false }
    }

    Component {
        id: comp
        Mixer { width: 824; height: 330 }
    }

    TestCase {
        name: "Mixer"
        when: windowShown

        function make(apps) {
            stage.changes = {}
            const record = (d, key, v) => { stage.changes[d.name + "." + key] = v }
            return createTemporaryObject(comp, stage, {
                setDefault: d => record(d, "default", true),
                setVolume: (d, v) => record(d, "volume", v),
                setMuted: (d, m) => record(d, "muted", m),
                outputs: [stage.device("Ryzen Speaker", "Speaker", true), stage.device("Ryzen Headphones", "Headphones", false)],
                inputs: [stage.device("Ryzen Digital Microphone", "Digital Microphone", true)],
                apps: apps === undefined ? [stage.app("Brave", 1), stage.app("Spotify", 0.6)] : apps
            })
        }

        function test_switch_output() {
            const m = make()
            const chip = findChild(m, "output-1")
            compare(chip.text, "Headphones")
            mouseClick(chip)
            compare(stage.changes["Ryzen Headphones.default"], true)
        }

        function test_scroll_system_volume() {
            const m = make()
            const slider = findChild(m, "outputVolume")
            mouseWheel(slider, slider.width / 2, slider.height / 2, 0, 120)
            fuzzyCompare(stage.changes["Ryzen Speaker.volume"], 0.55 * stage.full, 1)
        }

        function test_mute_output() {
            const m = make()
            mouseClick(findChild(m, "outputMute"))
            compare(stage.changes["Ryzen Speaker.muted"], true)
        }

        function test_drag_app_volume() {
            const m = make()
            const slider = findChild(m, "appVolume-1")
            mouseClick(slider, slider.width, slider.height / 2)
            fuzzyCompare(stage.changes["Spotify track.volume"], stage.full, 1)
        }

        function test_reset_apps() {
            const m = make()
            mouseClick(findChild(m, "resetApps"))
            compare(stage.changes["Spotify track.volume"], stage.full)
        }

        function test_no_apps() {
            const m = make([])
            compare(findChild(m, "noApps").visible, true)
        }
    }
}
