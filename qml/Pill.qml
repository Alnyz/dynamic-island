import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15
import QtQuick.Controls 2.15 as QQC
import org.kde.kirigami 2.19 as Kirigami

Rectangle {
    id: pill

    property string text
    property string iconName
    property string toolTip
    property bool primary: false
    property bool selected: false
    // Longer text is cut short with "…" and shown whole in the tooltip.
    property real maximumWidth: Infinity
    signal clicked()

    readonly property color ink: selected ? ipal.window : ipal.windowText

    height: 40
    readonly property real padding: height > 32 ? 36 : 26
    readonly property real iconSpace: iconName !== "" ? 16 + content.spacing : 0
    width: text === "" ? height : Math.min(maximumWidth, iconSpace + label.implicitWidth + padding)
    radius: height / 2
    color: primary ? (area.containsMouse ? Qt.lighter(ipal.accent, 1.15) : ipal.accent)
         : selected ? ipal.windowText
         : area.containsMouse ? ipal.button : (height > 32 ? ipal.alternateBase : ipal.base)

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8
        Kirigami.Icon {
            visible: pill.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: pill.iconName
            color: pill.ink
            isMask: true
        }
        Text {
            id: label
            visible: pill.text !== ""
            width: Math.min(implicitWidth, pill.width - pill.padding - pill.iconSpace)
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            text: pill.text
            color: pill.ink
            font.pixelSize: pill.height > 32 ? 13 : 12
            font.weight: pill.primary || pill.selected ? Font.DemiBold : Font.Normal
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: pill.clicked()
    }
    QQC.ToolTip.visible: (pill.toolTip !== "" || label.truncated) && area.containsMouse
    QQC.ToolTip.text: pill.toolTip !== "" ? pill.toolTip : pill.text
    QQC.ToolTip.delay: 500
}
