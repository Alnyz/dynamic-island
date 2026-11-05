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

    void testTakeRestoreDiscard()
    {
        QTemporaryDir dir;
        ClipboardHistory h(dir.path(), false);
        std::unique_ptr<QMimeData> a(textMime(QStringLiteral("first")));
        h.handleMime(a.get());
        QImage img(10, 10, QImage::Format_RGB32);
        img.fill(Qt::blue);
        QMimeData mime;
        mime.setImageData(img);
        h.handleMime(&mime);
        std::unique_ptr<QMimeData> c(textMime(QStringLiteral("last")));
        h.handleMime(c.get());
        QCOMPARE(h.items().size(), 3);
        const QVariantMap image = h.items().at(1).toMap();
        const QString file = QUrl(image.value(QStringLiteral("image")).toString()).toLocalFile();

        // Taken: gone from the list, file kept for undo.
        const QVariantMap taken = h.take(image.value(QStringLiteral("id")).toString());
        QCOMPARE(taken.value(QStringLiteral("index")).toInt(), 1);
        QCOMPARE(h.items().size(), 2);
        QVERIFY(QFile::exists(file));
        // Undo puts it back in place, and discarding afterwards leaves the file alone.
        h.restore(taken);
        QCOMPARE(h.items().size(), 3);
        QCOMPARE(h.items().at(1).toMap().value(QStringLiteral("id")), image.value(QStringLiteral("id")));
        h.discard(taken);
        QVERIFY(QFile::exists(file));
        // Taken again and the undo runs out: the file goes.
        const QVariantMap again = h.take(image.value(QStringLiteral("id")).toString());
        h.discard(again);
        QVERIFY(!QFile::exists(file));
        QVERIFY(h.take(QStringLiteral("missing")).isEmpty());
    }

    void testOrphanImagesDroppedOnLoad()
    {
        QTemporaryDir dir;
        QString file;
        {
            ClipboardHistory h(dir.path(), false);
            QImage img(10, 10, QImage::Format_RGB32);
            img.fill(Qt::green);
            QMimeData mime;
            mime.setImageData(img);
            h.handleMime(&mime);
            const QVariantMap item = h.items().at(0).toMap();
            file = QUrl(item.value(QStringLiteral("image")).toString()).toLocalFile();
            // The app quits while undo is still offered.
            h.take(item.value(QStringLiteral("id")).toString());
            QVERIFY(QFile::exists(file));
        }
        ClipboardHistory next(dir.path(), false);
        QVERIFY(!QFile::exists(file));
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
