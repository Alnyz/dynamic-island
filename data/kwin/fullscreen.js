// Loaded into KWin by the island (src/fullscreenwatcher.cpp). Reports the active window's
// screen and full-screen state, so the island knows when a game or film covers it.
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

function onActivated(w) {
    if (watched) {
        watched.fullScreenChanged.disconnect(reportFullScreen);
        watched.outputChanged.disconnect(reportFullScreen);
    }
    watched = w;
    if (w) {
        w.fullScreenChanged.connect(reportFullScreen);
        w.outputChanged.connect(reportFullScreen);
    }
    callDBus(SERVICE, PATH, IFACE, "reportActivated", outputOf(w), !!(w && w.fullScreen), w ? String(w.resourceClass) : "");
}

workspace.windowActivated.connect(onActivated);
onActivated(workspace.activeWindow);
