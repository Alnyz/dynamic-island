#include "appconfig.h"

#include <QFile>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>

class TestAppConfig : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase()
    {
        QStandardPaths::setTestModeEnabled(true);
    }

    void testCreatesPrivateFile()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("island.conf"));
        AppConfig config(path);
        QCOMPARE(config.path(), path);
        QVERIFY(QFile::exists(path));
        QCOMPARE(QFile::permissions(path) & (QFileDevice::ReadGroup | QFileDevice::ReadOther), QFileDevice::Permissions());
    }

    void testAutostartToggle()
    {
        QTemporaryDir dir;
        AppConfig config(dir.filePath(QStringLiteral("island.conf")));
        const QString entry = AppConfig::autostartPath();
        QFile::remove(entry);
        QCOMPARE(config.autostart(), false);

        config.setAutostart(true);
        QCOMPARE(config.autostart(), true);
        QFile file(entry);
        QVERIFY(file.open(QIODevice::ReadOnly));
        QVERIFY(file.readAll().contains("Exec="));
        file.close();

        config.setAutostart(false);
        QCOMPARE(config.autostart(), false);
        QVERIFY(!QFile::exists(entry));
    }
};

QTEST_GUILESS_MAIN(TestAppConfig)
#include "tst_appconfig.moc"
