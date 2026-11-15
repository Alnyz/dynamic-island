import QtQuick 2.15
import QtQuick.Window 2.15
import QtQml 2.15
import QtQml.Models 2.15
import org.kde.kirigami 2.19 as Kirigami

Item {
    id: button

    property string iconName
    property int iconSize: 20
    property color iconColor: ipal.windowText
    signal clicked()

    width: iconSize + 12
    height: iconSize + 12
    opacity: enabled ? 1 : 0.35

    Kirigami.Icon {
        anchors.centerIn: parent
        width: button.iconSize
        height: button.iconSize
        source: button.iconName
        color: button.iconColor
        isMask: true
    }
    MouseArea {
        anchors.fill: parent
        onClicked: button.clicked()
    }
}
