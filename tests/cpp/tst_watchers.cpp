#include "bluetoothwatcher.h"
#include "camerawatcher.h"
#include "notificationwatcher.h"
#include "plasmasettings.h"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>

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
