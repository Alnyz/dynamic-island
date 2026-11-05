import QtQuick

// The pill's cover on its way into the open panel. It lives on the window (the island's parent),
// so the centred island growing around it doesn't drag it along.
Item {
    id: flyer
    objectName: "coverFlyer"

    property var island: null
    // The panel whose own cover stays hidden until this one lands.
    property var panel: null

    parent: island ? island.parent : null
    z: 1000
    visible: false
    property real progress: 0
    property int frame: 0
    property rect from: Qt.rect(0, 0, 0, 0)
    property var target: null
    // Re-read every frame: the panel's layout keeps moving while the island grows.
    readonly property rect to: {
        progress
        frame
        if (!target || !target.width)
            return from
        const p = target.mapToItem(flyer.parent, 0, 0)
        return Qt.rect(p.x, p.y, target.width, target.height)
    }
    x: from.x + (to.x - from.x) * progress
    y: from.y + (to.y - from.y) * progress
    width: from.width + (to.width - from.width) * progress
    height: width

    // Flies from item (the pill's cover) to target (the panel's), hiding panelItem's cover meanwhile.
    function fly(item, target, panelItem) {
        const p = item.mapToItem(flyer.parent, 0, 0)
        from = Qt.rect(p.x, p.y, item.width, item.height)
        flyer.target = target
        panel = panelItem
        progress = 0
        panelItem.coverHidden = true
        visible = true
        flight.restart()
    }
    // Freezes where it landed and hands over to the panel's cover.
    function land() {
        from = to
        progress = 0
        target = null
        visible = false
        if (panel)
            panel.coverHidden = false
        panel = null
    }

    CoverArt {
        anchors.fill: parent
        radius: Math.round(width * 0.2)
        source: flyer.island && flyer.island.player ? flyer.island.artUrl : ""
        fallbackIcon: flyer.island && flyer.island.player ? flyer.island.player.iconName || flyer.island.player.desktopEntry || "" : ""
    }
    NumberAnimation on progress {
        id: flight
        running: false
        from: 0
        to: 1
        duration: 380
        easing.type: Easing.OutCubic
    }
    FrameAnimation {
        running: flyer.visible
        onTriggered: {
            flyer.frame++
            // Lands once it has arrived and the island has stopped growing.
            if (!flight.running && flyer.island.width === flyer.island.size.w && flyer.island.height === flyer.island.size.h)
                flyer.land()
        }
    }
}
