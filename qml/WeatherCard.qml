import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15
import org.kde.kirigami 2.19 as Kirigami
import "weather.js" as W

Column {
    id: card

    property var weather
    // Clicking the card asks to open a full forecast.
    signal forecastRequested(string url)
    readonly property var info: W.describe(weather ? weather.code : -1)
    readonly property bool hasData: weather !== null && weather !== undefined && !isNaN(weather.temperature)

    spacing: 14

    Row {
        visible: card.hasData
        spacing: 14
        Text {
            id: deg
            text: card.hasData ? card.weather.temperature + "°" : ""
            color: ipal.windowText
            font.pixelSize: 52
            font.weight: Font.ExtraLight
            font.letterSpacing: -1
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
                    color: ipal.windowText
                    isMask: true
                }
                Text {
                    text: card.info.text
                    color: ipal.windowText
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: card.hasData ? (card.weather.city ? card.weather.city + " · " : "") + "H " + card.weather.high + "° L " + card.weather.low + "°" : ""
                color: ipal.placeholderText
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
                    color: ipal.placeholderText
                    font.pixelSize: 11
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.temperature + "°"
                    color: ipal.windowText
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }
    }

    Text {
        visible: !card.hasData
        text: "Weather unavailable"
        color: ipal.placeholderText
        font.pixelSize: 12
    }

    // Handlers, not a MouseArea: a Column places its children itself.
    readonly property bool clickable: hasData && !!weather.forecastUrl
    TapHandler {
        enabled: card.clickable
        onTapped: card.forecastRequested(card.weather.forecastUrl)
    }
    HoverHandler {
        enabled: card.clickable
        cursorShape: Qt.PointingHandCursor
    }
}
