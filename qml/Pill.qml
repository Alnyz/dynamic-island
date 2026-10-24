import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

Rectangle {
    id: pill

    property string text
    property string iconName
    property string toolTip
    property bool primary: false
    property bool selected: false
    signal clicked()

    readonly property color ink: selected ? "#000000" : "#ffffff"

    height: 40
    width: text === "" ? height : content.implicitWidth + (height > 32 ? 36 : 26)
    radius: height / 2
    color: primary ? (area.containsMouse ? Qt.lighter(palette.accent, 1.15) : palette.accent)
         : selected ? "#ffffff"
         : area.containsMouse ? "#2a2a2a" : (height > 32 ? "#1f1f1f" : "#141414")

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
            visible: pill.text !== ""
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
    QQC.ToolTip.visible: pill.toolTip !== "" && area.containsMouse
    QQC.ToolTip.text: pill.toolTip
    QQC.ToolTip.delay: 500
}
