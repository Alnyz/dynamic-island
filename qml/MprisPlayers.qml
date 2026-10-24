import QtQuick
import org.kde.plasma.private.mpris as Mpris

// The only file that touches Plasma's private MPRIS module.
Item {
    id: root

    readonly property var list: containers

    property var containers: []

    function rebuild() {
        const out = []
        for (let i = 0; i < rows.count; ++i) {
            const c = rows.objectAt(i)?.container
            if (c)
                out.push(c)
        }
        containers = out
    }

    Instantiator {
        id: rows
        model: Mpris.Mpris2Model {}
        delegate: QtObject {
            required property var container
        }
        onObjectAdded: root.rebuild()
        onObjectRemoved: root.rebuild()
    }
}
