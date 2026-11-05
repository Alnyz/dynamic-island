#include "blursettings.h"

#include <KConfig>
#include <KConfigGroup>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class TestBlurSettings : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void groups()
    {
        QCOMPARE(BlurSettings::groupFor(QStringLiteral("better_blur_dx")), QStringLiteral("Effect-better-blur-dx"));
        QCOMPARE(BlurSettings::groupFor(QStringLiteral("blur")), QStringLiteral("Effect-blur"));
        QCOMPARE(BlurSettings::groupFor(QStringLiteral("forceblur")), QStringLiteral("Effect-forceblur"));
    }

    void readsDefaultAndWritesClamped()
    {
        QTemporaryDir dir;
        const QString file = dir.filePath(QStringLiteral("kwinrc"));
        BlurSettings s(file, QStringLiteral("better_blur_dx"));
        QCOMPARE(s.strength(), BlurSettings::kDefaultStrength);
        QSignalSpy changed(&s, &BlurSettings::changed);
        s.setStrength(5);
        QCOMPARE(s.strength(), 5);
        QCOMPARE(changed.count(), 1);
        // Written where the effect reads it, leaving other keys alone.
        KConfig config(file, KConfig::SimpleConfig);
        QCOMPARE(config.group(QStringLiteral("Effect-better-blur-dx")).readEntry("BlurStrength", 0), 5);
        s.setStrength(40);
        QCOMPARE(s.strength(), 15);
        s.setStrength(0);
        QCOMPARE(s.strength(), 1);
        // Same value: no change signal.
        const int before = changed.count();
        s.setStrength(1);
        QCOMPARE(changed.count(), before);
    }

    void keepsOtherSettings()
    {
        QTemporaryDir dir;
        const QString file = dir.filePath(QStringLiteral("kwinrc"));
        {
            KConfig config(file, KConfig::SimpleConfig);
            config.group(QStringLiteral("Effect-better-blur-dx")).writeEntry("NoiseStrength", 3);
            config.group(QStringLiteral("Plugins")).writeEntry("better_blur_dxEnabled", true);
            config.sync();
        }
        BlurSettings s(file, QStringLiteral("better_blur_dx"));
        s.setStrength(8);
        KConfig config(file, KConfig::SimpleConfig);
        QCOMPARE(config.group(QStringLiteral("Effect-better-blur-dx")).readEntry("NoiseStrength", 0), 3);
        QCOMPARE(config.group(QStringLiteral("Plugins")).readEntry("better_blur_dxEnabled", false), true);
    }

    void noEffectDoesNothing()
    {
        QTemporaryDir dir;
        const QString file = dir.filePath(QStringLiteral("kwinrc"));
        BlurSettings s(file, QString());
        s.setStrength(3);
        QVERIFY(!QFile::exists(file));
        QCOMPARE(s.strength(), BlurSettings::kDefaultStrength);
    }
};

QTEST_GUILESS_MAIN(TestBlurSettings)
#include "tst_blursettings.moc"
