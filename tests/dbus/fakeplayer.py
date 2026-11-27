# A silent stand-in MPRIS player for mprisplayers.qml:
# python3 fakeplayer.py <busname suffix> <identity> <title> <position_us> <rate>
import sys, dbus, dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
suffix, ident, title, pos, rate = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), float(sys.argv[5])
P = "org.mpris.MediaPlayer2.Player"; R = "org.mpris.MediaPlayer2"; PROPS = "org.freedesktop.DBus.Properties"
class Player(dbus.service.Object):
    def __init__(s, bus):
        super().__init__(bus, "/org/mpris/MediaPlayer2")
        s.st = {"title": title, "pos": pos, "rate": rate}
    def meta(s):
        return dbus.Dictionary({"mpris:trackid": dbus.ObjectPath("/t/" + str(abs(hash(s.st["title"])))),
            "xesam:title": s.st["title"], "xesam:artist": dbus.Array(["Nobody"], signature="s"),
            "mpris:length": dbus.Int64(300_000_000)}, signature="sv")
    def player(s):
        return {"PlaybackStatus": "Playing", "Rate": dbus.Double(s.st["rate"]), "Metadata": s.meta(),
                "Position": dbus.Int64(s.st["pos"]), "CanSeek": True, "CanControl": True, "CanPlay": True, "CanPause": True}
    @dbus.service.method(PROPS, in_signature="ss", out_signature="v", async_callbacks=("ok", "err"))
    def Get(s, i, n, ok, err):
        v = (s.player() if i == P else s.GetAll(i))[n]
        if n == "Position" and s.st.get("slow"):
            GLib.timeout_add(400, lambda: (ok(v), False)[1])
        else:
            ok(v)
    # Test hooks, reached through Seek(offset): 1 halves to 0.5x, 2 enables slow Position replies,
    # 3 changes the song, 4 seeks to 42 s.
    @dbus.service.method(P, in_signature="x")
    def Seek(s, o):
        if o == 1: s.SetRate(0.5)
        elif o == 2: s.st["slow"] = True
        elif o == 3: s.SetTitle("Another song")
        elif o == 4: s.DoSeek(42_000_000)
    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(s, i):
        return s.player() if i == P else {"Identity": ident, "DesktopEntry": "", "CanRaise": False}
    @dbus.service.signal(PROPS, signature="sa{sv}as")
    def PropertiesChanged(s, i, c, inv): pass
    @dbus.service.signal(P, signature="x")
    def Seeked(s, p): pass
    @dbus.service.method("org.test.Control", in_signature="d")
    def SetRate(s, r):
        s.st["rate"] = r; s.PropertiesChanged(P, {"Rate": dbus.Double(r)}, [])
    @dbus.service.method("org.test.Control", in_signature="x")
    def SetPos(s, p):
        s.st["pos"] = p
    @dbus.service.method("org.test.Control", in_signature="x")
    def DoSeek(s, p):
        s.st["pos"] = p; s.Seeked(dbus.Int64(p))
    @dbus.service.method("org.test.Control", in_signature="s")
    def SetTitle(s, t):
        s.st["title"] = t; s.PropertiesChanged(P, {"Metadata": s.meta()}, [])
bus = dbus.SessionBus()
name = dbus.service.BusName("org.mpris.MediaPlayer2." + suffix, bus)
p = Player(bus)
GLib.MainLoop().run()
