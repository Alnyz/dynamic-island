// Loaded into KWin by the island (src/fullscreenwatcher.cpp). Reports the active window's
// screen and full-screen state, so the island knows when a game or film covers it, and keeps the
// island above Plasma's panels.
const SERVICE = "io.github.alnyz.DynamicIsland";
const PATH = "/FullScreen";
const IFACE = "io.github.alnyz.DynamicIsland.FullScreen";

let watched = null;

function outputOf(w) {
    return w && w.output ? w.output.name : "";
}

function reportFullScreen() {
    if (watched)
        callDBus(SERVICE, PATH, IFACE, "reportFullScreen", outputOf(watched), !!watched.fullScreen);
}

// A full-screen game that closes may leave no window active, so its closing clears the state.
function onClosed() {
    watched = null;
    callDBus(SERVICE, PATH, IFACE, "reportFullScreen", "", false);
}

function onActivated(w) {
    if (watched) {
        watched.fullScreenChanged.disconnect(reportFullScreen);
        watched.outputChanged.disconnect(reportFullScreen);
        watched.closed.disconnect(onClosed);
    }
    watched = w;
    if (w) {
        w.fullScreenChanged.connect(reportFullScreen);
        w.outputChanged.connect(reportFullScreen);
        w.closed.connect(onClosed);
    }
    callDBus(SERVICE, PATH, IFACE, "reportActivated", outputOf(w), !!(w && w.fullScreen), w ? String(w.resourceClass) : "");
}

workspace.windowActivated.connect(onActivated);
onActivated(workspace.activeWindow);

// The island and Plasma's panels share KWin's dock layer, where the last one shown sits on top.
// Panels created or shown after the island (at login, after unlocking, when Plasma restarts or a
// panel add-on reloads) would cover it until it's activated. Whenever a panel or the island
// restacks, a panel above the island in the same layer puts the island back on top. Raising the
// island restacks it again, but then nothing is above it, so this settles at once.
function keepIslandOnTop() {
    const order = workspace.stackingOrder;
    let at = -1;
    for (let i = 0; i < order.length; ++i) {
        if (order[i].resourceClass === "dynamic-island")
            at = i;
    }
    if (at < 0)
        return;
    const island = order[at];
    for (let i = at + 1; i < order.length; ++i) {
        if (order[i].dock && order[i].resourceClass !== "dynamic-island" && order[i].layer === island.layer) {
            workspace.raiseWindow(island);
            return;
        }
    }
}

function watchStacking(w) {
    if (!w || !(w.dock || w.resourceClass === "dynamic-island"))
        return;
    w.stackingOrderChanged.connect(keepIslandOnTop);
    w.hiddenChanged.connect(keepIslandOnTop);
    keepIslandOnTop();
}

workspace.windowAdded.connect(watchStacking);
workspace.windowList().forEach(watchStacking);
