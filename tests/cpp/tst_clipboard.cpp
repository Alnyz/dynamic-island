#include "clipboardhistory.h"

#include <QFile>
#include <QImage>
#include <QMimeData>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>
#include <memory>


class TestClipboard : public QObject
{
    Q_OBJECT

    static QMimeData *textMime(const QString &text)
    {
        auto *mime = new QMimeData;
        mime->setText(text);
        return mime;
    }

    static QString textAt(const ClipboardHistory &h, int i)
    {
        return h.items().at(i).toMap().value(QStringLiteral("text")).toString();
    }

private Q_SLOTS:
    void testAddsNewestFirstAndDetectsLinks()
    {
        QTemporaryDir dir;
        ClipboardHistory h(dir.path(), false);
        std::unique_ptr<QMimeData> a(textMime(QStringLiteral("hello")));
        std::unique_ptr<QMimeData> b(textMime(QStringLiteral("  https://example.com/x  ")));
        h.handleMime(a.get());
        h.handleMime(b.get());
        QCOMPARE(h.items().size(), 2);
        QCOMPARE(textAt(h, 0), QStringLiteral("https://example.com/x"));
        QCOMPARE(h.items().at(0).toMap().value(QStringLiteral("kind")).toString(), QStringLiteral("link"));
        QCOMPARE(h.items().at(1).toMap().value(QStringLiteral("kind")).toString(), QStringLiteral("text"));
    }

    void testCopyingAgainMovesToTopAndKeepsPin()
    {
        QTemporaryDir dir;
        ClipboardHistory h(dir.path(), false);
        std::unique_ptr<QMimeData> a(textMime(QStringLiteral("a")));
        std::unique_ptr<QMimeData> b(textMime(QStringLiteral("b")));
        h.handleMime(a.get());
        h.pin(h.items().at(0).toMap().value(QStringLiteral("id")).toString(), true);
        h.handleMime(b.get());
        h.handleMime(a.get());
        QCOMPARE(h.items().size(), 2);
        QCOMPARE(textAt(h, 0), QStringLiteral("a"));
        QVERIFY(h.items().at(0).toMap().value(QStringLiteral("pinned")).toBool());
    }

    void testSameAsNewestKeepsItsTime()
    {
        QTemporaryDir dir;
        ClipboardHistory h(dir.path(), false);
        std::unique_ptr<QMimeData> a(textMime(QStringLiteral("a")));
        h.handleMime(a.get());
        const qint64 first = h.items().at(0).toMap().value(QStringLiteral("time")).toLongLong();
        QTest::qWait(5);
        h.handleMime(a.get());
        QCOMPARE(h.items().at(0).toMap().value(QStringLiteral("time")).toLongLong(), first);
    }

    void testSkipsPasswordsAndBlank()
    {
        QTemporaryDir dir;
        ClipboardHistory h(dir.path(), false);
        std::unique_ptr<QMimeData> secret(textMime(QStringLiteral("hunter2")));
        secret->setData(QStringLiteral("x-kde-passwordManagerHint"), "secret");
        std::unique_ptr<QMimeData> blank(textMime(QStringLiteral("   \n")));
        h.handleMime(secret.get());
        h.handleMime(blank.get());
        QCOMPARE(h.items().size(), 0);
    }

    void testKeepsFiftyPlusPinned()
    {
        QTemporaryDir dir;
        ClipboardHistory h(dir.path(), false);
        std::unique_ptr<QMimeData> first(textMime(QStringLiteral("keep me")));
        h.handleMime(first.get());
        h.pin(h.items().at(0).toMap().value(QStringLiteral("id")).toString(), true);
        for (int i = 0; i < 60; ++i) {
            std::unique_ptr<QMimeData> m(textMime(QString::number(i)));
            h.handleMime(m.get());
        }
        QCOMPARE(h.items().size(), 51);
        QCOMPARE(textAt(h, 50), QStringLiteral("keep me"));
        QCOMPARE(textAt(h, 49), QStringLiteral("10"));
    }

    void testImagesAreSavedAndRemoved()
    {
        QTemporaryDir dir;
        ClipboardHistory h(dir.path(), false);
        QImage img(40, 20, QImage::Format_RGB32);
        img.fill(Qt::red);
        QMimeData mime;
        mime.setImageData(img);
        h.handleMime(&mime);
        h.handleMime(&mime);
        QCOMPARE(h.items().size(), 1);
        const QVariantMap item = h.items().at(0).toMap();
        QCOMPARE(item.value(QStringLiteral("kind")).toString(), QStringLiteral("image"));
        QCOMPARE(item.value(QStringLiteral("width")).toInt(), 40);
        const QString file = QUrl(item.value(QStringLiteral("image")).toString()).toLocalFile();
        QVERIFY(QFile::exists(file));
        h.remove(item.value(QStringLiteral("id")).toString());
        QVERIFY(!QFile::exists(file));
        QCOMPARE(h.items().size(), 0);
    }

    void testClearKeepsPinnedAndHistoryReloads()
    {
        QTemporaryDir dir;
        {
            ClipboardHistory h(dir.path(), false);
            std::unique_ptr<QMimeData> a(textMime(QStringLiteral("pinned one")));
            std::unique_ptr<QMimeData> b(textMime(QStringLiteral("loose")));
            h.handleMime(a.get());
            h.pin(h.items().at(0).toMap().value(QStringLiteral("id")).toString(), true);
            h.handleMime(b.get());
            h.clear();
            QCOMPARE(h.items().size(), 1);
        }
        ClipboardHistory again(dir.path(), false);
        QCOMPARE(again.items().size(), 1);
        QCOMPARE(textAt(again, 0), QStringLiteral("pinned one"));
        const QFile::Permissions perms = QFile::permissions(dir.filePath(QStringLiteral("history.json")));
        QCOMPARE(perms & (QFileDevice::ReadGroup | QFileDevice::ReadOther), QFileDevice::Permissions());
    }
};

QTEST_GUILESS_MAIN(TestClipboard)
#include "tst_clipboard.moc"
