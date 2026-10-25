import QtQuick
import "logic.js" as L

// The saved notifications, newest first. Main.qml writes them to NotificationLog on itemsEdited.
QtObject {
    id: model

    property var now: () => Date.now()
    property var items: []
    // Rows that arrived after this (ms) count as new, unless clicked.
    property real lastSeen: 0
    property var settings: ({ save: true, system: true, apps: true, others: true, off: [], days: 7 })
    // Every app that has sent something, for the per-app switches in Settings.
    property var apps: []
    readonly property int newCount: settings.save ? L.newCount(items, lastSeen) : 0
    readonly property var groups: L.historyGroups(items)

    signal itemsEdited(var items)
    signal appsEdited(var apps)

    function add(n) {
        const known = L.rememberApp(apps, n)
        if (known !== apps) {
            apps = known
            appsEdited(apps)
        }
        if (L.historyAllowed(n, settings))
            edit(L.historyAdd(items, n, now(), settings.days))
    }

    function markSeen(id) { edit(items.map(r => r.id === id ? Object.assign({}, r, { seen: true }) : r)) }
    function remove(id) { edit(items.filter(r => r.id !== id)) }
    function clear() { edit([]) }
    function leave() { lastSeen = now() }

    function prune() {
        const kept = L.historyPrune(items, now(), settings.days)
        if (kept.length !== items.length)
            edit(kept)
    }

    function edit(next) {
        items = next
        itemsEdited(items)
    }
}
