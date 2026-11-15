import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15
import org.kde.kirigami 2.19 as Kirigami
import "logic.js" as L

// The first-run tour on the pill: one card per step of L.TOUR.
Slide {
    // The Island this card belongs to.
    property var island: null
    shown: island.mode === "tour"
    readonly property var step: L.TOUR[Math.min(island.tourStep, L.TOUR.length - 1)]
    Kirigami.Icon {
        id: tourIcon
        x: 18
        y: 18
        width: 28
        height: 28
        source: parent.step.icon
        color: ipal.accent
        isMask: true
    }
    Column {
        anchors.left: tourIcon.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 14
        spacing: 3
        Text {
            objectName: "tourTitle"
            width: parent.width
            text: parent.parent.step.title
            color: ipal.windowText
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            objectName: "tourBody"
            width: parent.width
            text: parent.parent.step.body
            color: ipal.text
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
    Row {
        x: 18 + 28 + 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        spacing: 5
        Repeater {
            model: L.TOUR.length
            delegate: Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: index === island.tourStep ? 14 : 6
                height: 6
                radius: 3
                color: index === island.tourStep ? ipal.windowText : Qt.rgba(ipal.windowText.r, ipal.windowText.g, ipal.windowText.b, 0.3)
                Behavior on width { NumberAnimation { duration: 150 } }
            }
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 6
        Rectangle {
            objectName: "tourSkip"
            visible: island.tourStep + 1 < L.TOUR.length
            width: skipText.implicitWidth + 22
            height: 26
            radius: 13
            color: skipArea.containsMouse ? Qt.rgba(ipal.windowText.r, ipal.windowText.g, ipal.windowText.b, 0.12) : "transparent"
            Text { id: skipText; anchors.centerIn: parent; text: "Skip"; color: ipal.placeholderText; font.pixelSize: 12 }
            MouseArea { id: skipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: island.skipTour() }
        }
        Rectangle {
            objectName: "tourNext"
            width: nextText.implicitWidth + 26
            height: 26
            radius: 13
            color: nextArea.containsMouse ? Qt.lighter(ipal.accent, 1.15) : ipal.accent
            Text {
                id: nextText
                anchors.centerIn: parent
                text: island.tourStep + 1 < L.TOUR.length ? "Next" : "Got it"
                color: "#ffffff"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: island.nextTourStep() }
        }
    }
}
