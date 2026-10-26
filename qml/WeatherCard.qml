import QtQuick
import org.kde.kirigami as Kirigami
import "weather.js" as W

Column {
    id: card

    property var weather
    readonly property var info: W.describe(weather ? weather.code : -1)
    readonly property bool hasData: weather !== null && weather !== undefined && !isNaN(weather.temperature)

    spacing: 14

    Row {
        visible: card.hasData
        spacing: 14
        Text {
            id: deg
            text: card.hasData ? card.weather.temperature + "°" : ""
            color: "#ffffff"
            font.pixelSize: 52
            font.weight: Font.ExtraLight
            font.letterSpacing: -1
            font.features: { "tnum": 1 }
        }
        Column {
            anchors.bottom: deg.baseline
            width: card.width - deg.width - parent.spacing
            spacing: 2
            Row {
                spacing: 6
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    source: card.info.icon
                    color: "#ffffff"
                    isMask: true
                }
                Text {
                    text: card.info.text
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: card.hasData ? (card.weather.city ? card.weather.city + " · " : "") + "H " + card.weather.high + "° L " + card.weather.low + "°" : ""
                color: "#9aa3ad"
                font.pixelSize: 12
            }
        }
    }

    Row {
        visible: card.hasData && card.weather.hours.length > 0
        spacing: 18
        Repeater {
            model: card.hasData ? card.weather.hours : []
            delegate: Column {
                required property var modelData
                spacing: 4
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.hour + ":00"
                    color: "#9aa3ad"
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.temperature + "°"
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    Text {
        visible: !card.hasData
        text: "Weather unavailable"
        color: "#9aa3ad"
        font.pixelSize: 12
    }
}
