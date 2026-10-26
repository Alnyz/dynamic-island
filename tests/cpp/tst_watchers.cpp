#include "bluetoothwatcher.h"
#include "camerawatcher.h"
#include "fullscreenwatcher.h"
#include "inputregion.h"
#include <QDBusConnection>
#include "jobwatcher.h"
#include "notificationwatcher.h"
#include "plasmasettings.h"

#include <QDir>
#include <QSignalSpy>
#include <dbus/dbus.h>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>

namespace
{
DBusMessage *jobUpdate()
{
    DBusMessage *m = dbus_message_new_method_call(nullptr, "/org/kde/notificationmanager/jobs/JobView_3", "org.kde.JobViewV3", "update");
    dbus_message_set_sender(m, ":1.131");
    DBusMessageIter it, dict;
    dbus_message_iter_init_append(m, &it);
    dbus_message_iter_open_container(&it, DBUS_TYPE_ARRAY, "{sv}", &dict);
    auto add = [&](const char *key, int type, const char *sig, const void *value) {
        DBusMessageIter entry, variant;
        dbus_message_iter_open_container(&dict, DBUS_TYPE_DICT_ENTRY, nullptr, &entry);
        dbus_message_iter_append_basic(&entry, DBUS_TYPE_STRING, &key);
        dbus_message_iter_open_container(&entry, DBUS_TYPE_VARIANT, sig, &variant);
        dbus_message_iter_append_basic(&variant, type, value);
        dbus_message_iter_close_container(&entry, &variant);
        dbus_message_iter_close_container(&dict, &entry);
    };
    const char *title = "Copying";
    const char *dest = "/home/alnyz/Downloads/big.bin";
    const dbus_uint32_t percent = 64;
    const dbus_uint64_t total = 2147483648ULL;
    add("title", DBUS_TYPE_STRING, "s", &title);
    add("percent", DBUS_TYPE_UINT32, "u", &percent);
    add("totalBytes", DBUS_TYPE_UINT64, "t", &total);
    add("descriptionValue2", DBUS_TYPE_STRING, "s", &dest);
    dbus_message_iter_close_container(&it, &dict);
    return m;
}

DBusMessage *ownerChanged(const char *name, const char *newOwner)
{
    DBusMessage *m = dbus_message_new_signal("/org/freedesktop/DBus", "org.freedesktop.DBus", "NameOwnerChanged");
    dbus_message_set_sender(m, "org.freedesktop.DBus");
    dbus_message_append_args(m, DBUS_TYPE_STRING, &name, DBUS_TYPE_STRING, &name, DBUS_TYPE_STRING, &newOwner, DBUS_TYPE_INVALID);
    return m;
}
}

class TestWatchers : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void testNotificationDescribe()
    {
        const QVariantMap n = NotificationWatcher::describe(QStringLiteral("Discord"), QString(), QStringLiteral(" Rizky "),
                                                            QStringLiteral("jadi <b>besok</b>\njam 10"), {{QStringLiteral("desktop-entry"), QStringLiteral("discord")}});
        QCOMPARE(n.value(QStringLiteral("title")).toString(), QStringLiteral("Rizky"));
        QCOMPARE(n.value(QStringLiteral("body")).toString(), QStringLiteral("jadi besok jam 10"));
        QCOMPARE(n.value(QStringLiteral("icon")).toString(), QStringLiteral("discord"));
        QCOMPARE(n.value(QStringLiteral("desktopEntry")).toString(), QStringLiteral("discord"));

        const QVariantMap path = NotificationWatcher::describe(QStringLiteral("x"), QStringLiteral("/tmp/a.png"), QStringLiteral("t"), QString(), {});
        QCOMPARE(path.value(QStringLiteral("icon")).toString(), QStringLiteral("file:///tmp/a.png"));
        QVERIFY(NotificationWatcher::describe(QStringLiteral("x"), QString(), QStringLiteral(" "), QString(), {}).isEmpty());
    }

    void testNotifyReplaces()
    {
        DBusMessage *m = dbus_message_new_method_call(nullptr, "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "Notify");
        const char *app = "Telegram", *icon = "", *summary = "Rina", *body = "hi";
        const dbus_uint32_t replaces = 7;
        const dbus_int32_t timeout = -1;
        DBusMessageIter it, actions, hints;
        dbus_message_iter_init_append(m, &it);
        dbus_message_iter_append_basic(&it, DBUS_TYPE_STRING, &app);
        dbus_message_iter_append_basic(&it, DBUS_TYPE_UINT32, &replaces);
        dbus_message_iter_append_basic(&it, DBUS_TYPE_STRING, &icon);
        dbus_message_iter_append_basic(&it, DBUS_TYPE_STRING, &summary);
        dbus_message_iter_append_basic(&it, DBUS_TYPE_STRING, &body);
        dbus_message_iter_open_container(&it, DBUS_TYPE_ARRAY, "s", &actions);
        dbus_message_iter_close_container(&it, &actions);
        dbus_message_iter_open_container(&it, DBUS_TYPE_ARRAY, "{sv}", &hints);
        {
            DBusMessageIter entry, variant;
            const char *key = "urgency";
            const unsigned char critical = 2;
            dbus_message_iter_open_container(&hints, DBUS_TYPE_DICT_ENTRY, nullptr, &entry);
            dbus_message_iter_append_basic(&entry, DBUS_TYPE_STRING, &key);
            dbus_message_iter_open_container(&entry, DBUS_TYPE_VARIANT, "y", &variant);
            dbus_message_iter_append_basic(&variant, DBUS_TYPE_BYTE, &critical);
            dbus_message_iter_close_container(&entry, &variant);
            dbus_message_iter_close_container(&hints, &entry);
        }
        dbus_message_iter_close_container(&it, &hints);
        dbus_message_iter_append_basic(&it, DBUS_TYPE_INT32, &timeout);

        NotificationWatcher watcher;
        QSignalSpy notified(&watcher, &NotificationWatcher::notified);
        watcher.handle(m);
        QCOMPARE(notified.count(), 1);
        QCOMPARE(notified.first().first().toMap().value(QStringLiteral("replaces")).toInt(), 7);
        QCOMPARE(notified.first().first().toMap().value(QStringLiteral("urgency")).toInt(), 2);
        dbus_message_unref(m);
    }

    void fullScreenWatcher()
    {
        FullScreenWatcher w;
        w.setScreenName(QStringLiteral("eDP-1"));
        QSignalSpy switched(&w, &FullScreenWatcher::switched);
        w.reportActivated(QStringLiteral("eDP-1"), true, QStringLiteral("steam_app_1"));
        QVERIFY(w.active());
        QCOMPARE(switched.count(), 1);
        w.reportActivated(QString(), false, QString());
        QVERIFY(w.active());
        w.reportActivated(QStringLiteral("eDP-1"), false, QStringLiteral("dynamic-island"));
        QVERIFY(w.active());
        QCOMPARE(switched.count(), 1);
        w.reportFullScreen(QStringLiteral("eDP-1"), false);
        QVERIFY(!w.active());
        QCOMPARE(switched.count(), 1);
        w.reportActivated(QStringLiteral("HDMI-A-1"), true, QStringLiteral("mpv"));
        QVERIFY(!w.active());
        QCOMPARE(switched.count(), 2);
    }

    void emptyInputRegionStaysSmall()
    {
        // An empty mask means "no mask" on Wayland: the whole window would take clicks.
        QCOMPARE(InputRegion::maskRect(QRectF(380, 0, 120, 0)), QRect(380, 0, 1, 1));
        QCOMPARE(InputRegion::maskRect(QRectF(300, 0, 300.4, 32)), QRect(300, 0, 301, 32));
    }

    void fullScreenWatcherWithoutServiceLoadsNothing()
    {
        // Another instance (here: the test) already owns the name, so this one must neither load
        // nor, on destruction, unload the other instance's KWin script.
        auto bus = QDBusConnection::sessionBus();
        const bool mine = bus.registerService(QStringLiteral("io.github.alnyz.DynamicIsland"));
        {
            FullScreenWatcher w;
            w.setEnabled(true);
            QVERIFY(!w.loaded());
        }
        if (mine)
            bus.unregisterService(QStringLiteral("io.github.alnyz.DynamicIsland"));
    }

    void notificationUrgency()
    {
        const QVariantMap critical = NotificationWatcher::describe(QStringLiteral("x"), QString(), QStringLiteral("t"), QString(), {{QStringLiteral("urgency"), 2}});
        QCOMPARE(critical.value(QStringLiteral("urgency")).toInt(), 2);
        const QVariantMap plain = NotificationWatcher::describe(QStringLiteral("x"), QString(), QStringLiteral("t"), QString(), {});
        QCOMPARE(plain.value(QStringLiteral("urgency")).toInt(), 1);
    }

    void testBluetoothDescribe()
    {
        const QVariantMap d = BluetoothWatcher::describe({{QStringLiteral("Alias"), QStringLiteral("Galaxy Buds2")}, {QStringLiteral("Icon"), QStringLiteral("audio-headset")}},
                                                         {{QStringLiteral("Percentage"), 82}}, true);
        QCOMPARE(d.value(QStringLiteral("name")).toString(), QStringLiteral("Galaxy Buds2"));
        QCOMPARE(d.value(QStringLiteral("icon")).toString(), QStringLiteral("audio-headset"));
        QCOMPARE(d.value(QStringLiteral("battery")).toInt(), 82);
        QCOMPARE(BluetoothWatcher::describe({{QStringLiteral("Name"), QStringLiteral("Mouse")}}, {}, false).value(QStringLiteral("battery")).toInt(), -1);
    }

    void testPlasmaSettings()
    {
        QTemporaryDir dir;
        QFile rc(dir.filePath(QStringLiteral("plasmanotifyrc")));
        QVERIFY(rc.open(QIODevice::WriteOnly));
        rc.write("[Applications][discord]\nSeen=true\n\n[Applications][brave-browser]\nSeen=true\n");
        rc.close();
        PlasmaSettings s(dir.path());

        s.setOsdEnabled(false);
        QCOMPARE(s.osdEnabled(), false);
        s.setOsdEnabled(true);
        QCOMPARE(s.osdEnabled(), true);

        s.setPopupsEnabled(false);
        QCOMPARE(s.popupsEnabled(QStringLiteral("discord")), false);
        QCOMPARE(s.popupsEnabled(QStringLiteral("brave-browser")), false);
        s.hidePopupsFor(QStringLiteral("org.telegram.desktop"));
        QCOMPARE(s.popupsEnabled(QStringLiteral("org.telegram.desktop")), false);
        s.setPopupsEnabled(true);
        QCOMPARE(s.popupsEnabled(QStringLiteral("discord")), true);
        QCOMPARE(s.popupsEnabled(QStringLiteral("org.telegram.desktop")), true);
    }

    void testJobReadProps()
    {
        DBusMessage *m = jobUpdate();
        const QVariantMap p = JobWatcher::readProps(m);
        QCOMPARE(p.value(QStringLiteral("title")).toString(), QStringLiteral("Copying"));
        QCOMPARE(p.value(QStringLiteral("percent")).toLongLong(), 64);
        QCOMPARE(p.value(QStringLiteral("totalBytes")).toLongLong(), 2147483648LL);
        QCOMPARE(p.value(QStringLiteral("descriptionValue2")).toString(), QStringLiteral("/home/alnyz/Downloads/big.bin"));
        dbus_message_unref(m);
    }

    void testJobKey()
    {
        DBusMessage *m = jobUpdate();
        QCOMPARE(JobWatcher::key(m), QStringLiteral(":1.131 /org/kde/notificationmanager/jobs/JobView_3"));
        dbus_message_unref(m);
    }

    void testOwnerGone()
    {
        JobWatcher w;
        QSignalSpy gone(&w, &JobWatcher::ownerGone);
        DBusMessage *left = ownerChanged(":1.131", "");
        DBusMessage *moved = ownerChanged(":1.140", ":1.140");
        w.handle(left);
        w.handle(moved);
        QCOMPARE(gone.count(), 1);
        QCOMPARE(gone.first().first().toString(), QStringLiteral(":1.131"));
        dbus_message_unref(left);
        dbus_message_unref(moved);
    }

    void testCameraScan()
    {
        QTemporaryDir proc;
        auto fakeProcess = [&](const QString &pid, const QString &comm, const QString &target) {
            QDir(proc.path()).mkpath(pid + QStringLiteral("/fd"));
            QFile f(proc.filePath(pid + QStringLiteral("/comm")));
            QVERIFY(f.open(QIODevice::WriteOnly));
            f.write(comm.toUtf8() + "\n");
            f.close();
            QVERIFY(QFile::link(target, proc.filePath(pid + QStringLiteral("/fd/3"))));
        };
        fakeProcess(QStringLiteral("100"), QStringLiteral("brave"), QStringLiteral("/dev/video0"));
        fakeProcess(QStringLiteral("200"), QStringLiteral("konsole"), QStringLiteral("/dev/pts/1"));
        QCOMPARE(CameraWatcher::scan(proc.path()), QStringList{QStringLiteral("brave")});
    }
};

QTEST_MAIN(TestWatchers)
#include "tst_watchers.moc"
