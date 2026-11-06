#include "windowactivator.h"

#include <QTest>

class TestWindowActivator : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void hints()
    {
        QCOMPARE(WindowActivator::hintFromOrigin(QStringLiteral("web.whatsapp.com")), QStringLiteral("whatsapp"));
        QCOMPARE(WindowActivator::hintFromOrigin(QStringLiteral("mail.google.com")), QStringLiteral("google"));
        QCOMPARE(WindowActivator::hintFromOrigin(QStringLiteral("www.bbc.co.uk")), QStringLiteral("bbc"));
        QCOMPARE(WindowActivator::hintFromOrigin(QStringLiteral("discord.com")), QStringLiteral("discord"));
        QCOMPARE(WindowActivator::hintFromOrigin(QStringLiteral("localhost")), QStringLiteral("localhost"));
        QCOMPARE(WindowActivator::hintFromOrigin(QString()), QString());
    }

    void scriptQuotesItsInputs()
    {
        const QString s = WindowActivator::script(QStringLiteral("brave-browser"), QStringLiteral("whatsapp"));
        QVERIFY(s.contains(QStringLiteral("const entry = \"brave-browser\".toLowerCase();")));
        // Web-app windows of the browser count too.
        QVERIFY(s.contains(QStringLiteral("const family = entry.replace(")));
        QVERIFY(s.contains(QStringLiteral("const hint = \"whatsapp\".toLowerCase();")));
        QVERIFY(s.contains(QStringLiteral("workspace.activeWindow = best;")));
        // Without a bus name to report to, a miss does nothing.
        QVERIFY(!s.contains(QStringLiteral("callDBus")));
        const QString launching = WindowActivator::script(QStringLiteral("brave-browser"), QString(), QStringLiteral(":1.42"));
        QVERIFY(launching.contains(QStringLiteral("else {\n    callDBus(\":1.42\", \"/WindowActivator\", \"io.github.alnyz.DynamicIsland.WindowActivator\", \"noWindow\", \"brave-browser\");")));
        // Quotes and newlines in a hint can't break out of the string.
        const QString evil = WindowActivator::script(QStringLiteral("x"), QStringLiteral("a\"; workspace.windowList().forEach(w => w.closeWindow()); \"\n"));
        QVERIFY(evil.contains(QStringLiteral("const hint = \"a\\\"; workspace.windowList().forEach(w => w.closeWindow()); \\\"\\n\".toLowerCase();")));
    }
};

QTEST_GUILESS_MAIN(TestWindowActivator)
#include "tst_windowactivator.moc"
