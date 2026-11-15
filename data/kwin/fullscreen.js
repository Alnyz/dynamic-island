// Loaded into KWin by the island (src/fullscreenwatcher.cpp). Reports the active window's
// screen and full-screen state, so the island knows when a game or film covers it.
// KWin 5 (X11) version: windows are "clients", and screens are reported as the window's centre
// point ("x,y"), which the island maps to a screen name.
const SERVICE = "io.github.alnyz.DynamicIsland";
const PATH = "/FullScreen";
const IFACE = "io.github.alnyz.DynamicIsland.FullScreen";

let watched = null;

function outputOf(w) {
    if (!w)
        return "";
    const g = w.geometry;
    return Math.round(g.x + g.width / 2) + "," + Math.round(g.y + g.height / 2);
}

function reportFullScreen() {
    if (watched)
        callDBus(SERVICE, PATH, IFACE, "reportFullScreen", outputOf(watched), !!watched.fullScreen);
}

// A full-screen game that closes may leave no window active, so its closing clears the state.
function onRemoved(w) {
    if (w !== watched)
        return;
    watched = null;
    callDBus(SERVICE, PATH, IFACE, "reportFullScreen", "", false);
}

function onActivated(w) {
    if (watched) {
        watched.fullScreenChanged.disconnect(reportFullScreen);
        watched.screenChanged.disconnect(reportFullScreen);
    }
    watched = w;
    if (w) {
        w.fullScreenChanged.connect(reportFullScreen);
        w.screenChanged.connect(reportFullScreen);
    }
    callDBus(SERVICE, PATH, IFACE, "reportActivated", outputOf(w), !!(w && w.fullScreen), w ? String(w.resourceClass) : "");
}

workspace.clientActivated.connect(onActivated);
workspace.clientRemoved.connect(onRemoved);
onActivated(workspace.activeClient);
