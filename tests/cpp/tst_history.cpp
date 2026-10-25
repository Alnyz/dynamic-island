#include "notificationlog.h"

#include <QFile>
#include <QTemporaryDir>
#include <QTest>

class TestHistory : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void testSaveAndReload()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("notifications.json"));
        NotificationLog log(path);
        log.save({QVariantMap{{QStringLiteral("id"), QStringLiteral("a")}, {QStringLiteral("title"), QStringLiteral("Rina")}, {QStringLiteral("time"), 1000.0}}});
        QCOMPARE(log.items().size(), 1);
        NotificationLog again(path);
        QCOMPARE(again.items().size(), 1);
        const QVariantMap row = again.items().at(0).toMap();
        QCOMPARE(row.value(QStringLiteral("title")).toString(), QStringLiteral("Rina"));
        QCOMPARE(row.value(QStringLiteral("time")).toDouble(), 1000.0);
    }

    void testFileIsPrivate()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("notifications.json"));
        NotificationLog log(path);
        log.save({});
        const auto other = QFileDevice::ReadGroup | QFileDevice::WriteGroup | QFileDevice::ExeGroup | QFileDevice::ReadOther
            | QFileDevice::WriteOther | QFileDevice::ExeOther | QFileDevice::ExeOwner;
        const auto perms = QFile::permissions(path);
        QVERIFY(perms.testFlag(QFileDevice::ReadOwner) && perms.testFlag(QFileDevice::WriteOwner));
        QVERIFY(!(perms & other));
    }

    void testCorruptFile()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("notifications.json"));
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("{nope");
        f.close();
        NotificationLog log(path);
        QCOMPARE(log.items().size(), 0);
        log.save({});
        QVERIFY(f.open(QIODevice::ReadOnly));
        QCOMPARE(f.readAll().trimmed(), QByteArray("[]"));
    }

    void testMissingDirIsCreated()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("sub/notifications.json"));
        NotificationLog log(path);
        log.save({QVariantMap{{QStringLiteral("id"), QStringLiteral("a")}}});
        QVERIFY(QFile::exists(path));
    }
};

QTEST_GUILESS_MAIN(TestHistory)
#include "tst_history.moc"
