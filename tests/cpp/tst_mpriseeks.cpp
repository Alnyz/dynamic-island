#include "mpriseeks.h"

#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QSignalSpy>
#include <QTest>

class FakeRoot : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(QString Identity MEMBER identity)
public:
    explicit FakeRoot(QObject *parent) : QDBusAbstractAdaptor(parent) {}
    QString identity = QStringLiteral("mpv");
};

class FakePlayer : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(qlonglong Position MEMBER position)
    Q_PROPERTY(QVariantMap Metadata MEMBER metadata)
public:
    explicit FakePlayer(QObject *parent) : QDBusAbstractAdaptor(parent) {}
    qlonglong position = 0;
    QVariantMap metadata;
};

// One player on its own bus connection, as two running instances would be.
struct Fake {
    QObject object;
    QDBusConnection bus;
    FakePlayer *player;

    Fake(const QString &name, const QString &title, qlonglong position)
        : bus(QDBusConnection::connectToBus(QDBusConnection::SessionBus, name))
    {
        new FakeRoot(&object);
        player = new FakePlayer(&object);
        player->position = position;
        player->metadata = {{QStringLiteral("xesam:title"), title}};
        bus.registerObject(QStringLiteral("/org/mpris/MediaPlayer2"), &object);
        bus.registerService(QStringLiteral("org.mpris.MediaPlayer2.") + name);
    }
};

class TestMprisSeeks : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void testSameNameToldApartByTitle()
    {
        Fake one(QStringLiteral("mpv.instance1"), QStringLiteral("One"), 1000000);
        Fake two(QStringLiteral("mpv.instance2"), QStringLiteral("Two"), 2000000);
        MprisSeeks seeks;
        QSignalSpy read(&seeks, &MprisSeeks::positionRead);

        for (const auto &[title, position] : {std::pair{"Two", 2000000}, std::pair{"One", 1000000}}) {
            read.clear();
            seeks.askPosition(QStringLiteral("mpv"), QString::fromLatin1(title));
            QVERIFY(read.wait(2000));
            QCOMPARE(read.first().at(1).toString(), QString::fromLatin1(title));
            QCOMPARE(read.first().at(2).toLongLong(), position);
        }

        // The player found for a title moves on to another song: the other one now has it.
        one.player->metadata = {{QStringLiteral("xesam:title"), QStringLiteral("Three")}};
        two.player->metadata = {{QStringLiteral("xesam:title"), QStringLiteral("One")}};
        // The first ask drops the old one, the next (2 s later in the app) finds the new one.
        read.clear();
        seeks.askPosition(QStringLiteral("mpv"), QStringLiteral("One"));
        QVERIFY(!read.wait(300));
        seeks.askPosition(QStringLiteral("mpv"), QStringLiteral("One"));
        QVERIFY(read.wait(2000));
        QCOMPARE(read.first().at(2).toLongLong(), 2000000);
    }

    void testSeekedNamesTheSong()
    {
        Fake two(QStringLiteral("mpv.instance3"), QStringLiteral("Two"), 0);
        MprisSeeks seeks;
        QSignalSpy seeked(&seeks, &MprisSeeks::seeked);
        QDBusMessage m = QDBusMessage::createSignal(QStringLiteral("/org/mpris/MediaPlayer2"),
                                                    QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("Seeked"));
        m << qlonglong(5000000);
        two.bus.send(m);
        QVERIFY(seeked.wait(2000));
        QCOMPARE(seeked.first().at(0).toString(), QStringLiteral("mpv"));
        QCOMPARE(seeked.first().at(1).toString(), QStringLiteral("Two"));
        QCOMPARE(seeked.first().at(2).toLongLong(), 5000000);
    }
};

QTEST_GUILESS_MAIN(TestMprisSeeks)
#include "tst_mpriseeks.moc"
