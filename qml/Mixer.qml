import QtQuick
import org.kde.kirigami as Kirigami
import "logic.js" as L

// Devices and per-app volume. Works on PulseAudio objects from SoundSource (or look-alikes in tests).
Item {
    id: mixer

    property var outputs: []
    property var inputs: []
    property var apps: []
    // 0 to 1 live microphone level, or -1 when unknown.
    property real micLevel: -1
    readonly property real full: 65536
    // Changes go through these so tests can watch them; PulseAudio objects take plain assignment.
    property var setDefault: d => d.default = true
    property var setVolume: (d, v) => d.volume = v
    property var setMuted: (d, m) => d.muted = m

    readonly property var output: outputs.find(d => d.default) || outputs[0] || null
    readonly property var input: inputs.find(d => d.default) || inputs[0] || null

    function label(d) {
        return L.deviceLabel(d.description, d.ports && d.ports.length ? d.ports[d.activePortIndex].description : "")
    }

    Column {
        id: left
        width: 330
        spacing: 10

        Heading { text: "OUTPUT" }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: mixer.outputs
                delegate: Pill {
                    required property var modelData
                    required property int index
                    objectName: "output-" + index
                    height: 30
                    iconName: modelData.iconName || "audio-speakers"
                    text: mixer.label(modelData)
                    selected: mixer.output !== null && modelData.name === mixer.output.name
                    onClicked: mixer.setDefault(modelData)
                }
            }
        }
        DeviceVolume {
            device: mixer.output
            sliderName: "outputVolume"
            muteName: "outputMute"
            icon: "audio-volume-high"
        }

        Item { width: 1; height: 8 }
        Heading { text: "INPUT" }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: mixer.inputs
                delegate: Pill {
                    required property var modelData
                    required property int index
                    objectName: "input-" + index
                    height: 30
                    iconName: "audio-input-microphone"
                    text: mixer.label(modelData)
                    selected: mixer.input !== null && modelData.name === mixer.input.name
                    onClicked: mixer.setDefault(modelData)
                }
            }
        }
        DeviceVolume {
            device: mixer.input
            sliderName: "inputVolume"
            muteName: "inputMute"
            icon: "audio-input-microphone"
        }
        // Moves with your voice, so you can check the mic before a call.
        Rectangle {
            visible: mixer.micLevel >= 0
            x: 40
            width: parent.width - 88
            height: 3
            radius: 1.5
            color: "#1a1a1a"
            Rectangle {
                width: parent.width * Math.min(1, Math.max(0, mixer.micLevel))
                height: parent.height
                radius: parent.radius
                color: "#4ade80"
            }
        }
    }

    Column {
        anchors.left: left.right
        anchors.leftMargin: 34
        anchors.right: parent.right
        spacing: 6

        Item {
            width: parent.width
            height: appsHeading.height
            Heading { id: appsHeading; text: "APPS" }
            Text {
                objectName: "resetApps"
                visible: mixer.apps.length > 0
                anchors.right: parent.right
                text: "Reset all to 100%"
                color: resetArea.containsMouse ? Qt.lighter(palette.accent, 1.15) : palette.accent
                font.pixelSize: 12
                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: mixer.apps.forEach(a => mixer.setVolume(a, mixer.full))
                }
            }
        }

        Text {
            objectName: "noApps"
            visible: mixer.apps.length === 0
            topPadding: 6
            text: "No apps are playing sound"
            color: "#9aa3ad"
            font.pixelSize: 12
        }

        Repeater {
            model: mixer.apps
            delegate: Row {
                id: row
                required property var modelData
                required property int index
                readonly property string appName: (modelData.client && modelData.client.name) || modelData.properties["application.name"] || "App"
                width: parent.width
                height: 40
                spacing: 12

                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    source: row.modelData.properties["application.icon_name"] || row.appName.toLowerCase()
                    fallback: "application-x-executable"
                }
                Column {
                    width: 120
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: row.appName
                        color: row.modelData.muted ? "#8a929c" : "#ffffff"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.muted ? "Muted" : row.modelData.corked ? "Paused" : row.modelData.name
                        color: "#9aa3ad"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
                VolumeSlider {
                    objectName: "appVolume-" + row.index
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.width - 28 - 120 - 46 - 28 - 4 * row.spacing
                    value: row.modelData.volume / mixer.full
                    dimmed: row.modelData.muted
                    onMoved: v => mixer.setVolume(row.modelData, v * mixer.full)
                }
                Text {
                    width: 46
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(row.modelData.volume / mixer.full * 100) + "%"
                    color: "#9aa3ad"
                    font.pixelSize: 12
                    font.features: { "tnum": 1 }
                }
                MuteButton {
                    anchors.verticalCenter: parent.verticalCenter
                    muted: row.modelData.muted
                    onClicked: mixer.setMuted(row.modelData, !row.modelData.muted)
                }
            }
        }
    }

    component Heading: Text {
        color: "#9aa3ad"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
    }

    component MuteButton: Rectangle {
        id: mute
        property bool muted
        property string icon: "audio-volume-high"
        signal clicked()
        width: 28
        height: 28
        radius: 14
        color: muted ? "#3a1d1d" : muteArea.containsMouse ? "#1a1a1a" : "transparent"
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 15
            height: 15
            source: mute.muted ? "audio-volume-muted" : mute.icon
            color: mute.muted ? "#ff8a8a" : "#c7ccd3"
            isMask: true
        }
        MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: mute.clicked()
        }
    }

    component DeviceVolume: Row {
        id: dv
        property var device
        property string sliderName
        property string muteName
        property string icon
        visible: device !== null
        width: 330
        spacing: 10
        MuteButton {
            objectName: dv.muteName
            anchors.verticalCenter: parent.verticalCenter
            icon: dv.icon
            muted: dv.device ? dv.device.muted : false
            color: muted ? "#3a1d1d" : "#141414"
            onClicked: mixer.setMuted(dv.device, !dv.device.muted)
        }
        VolumeSlider {
            objectName: dv.sliderName
            anchors.verticalCenter: parent.verticalCenter
            width: dv.width - 28 - 46 - 2 * dv.spacing
            value: dv.device ? dv.device.volume / mixer.full : 0
            dimmed: dv.device ? dv.device.muted : false
            onMoved: v => mixer.setVolume(dv.device, v * mixer.full)
        }
        Text {
            width: 46
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: dv.device ? Math.round(dv.device.volume / mixer.full * 100) + "%" : ""
            color: "#9aa3ad"
            font.pixelSize: 12
            font.features: { "tnum": 1 }
        }
    }
}
