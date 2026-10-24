#include "notesstore.h"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>

class TestNotes : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void testWriteListsTitleAndPreview()
    {
        QTemporaryDir dir;
        NotesStore store(dir.path());
        const QString id = store.newId();
        QCOMPARE(store.notes().size(), 0);
        store.write(id, QStringLiteral("\nGroceries\n- eggs\n\n- coffee\n"));
        QCOMPARE(store.notes().size(), 1);
        const QVariantMap note = store.notes().at(0).toMap();
        QCOMPARE(note.value(QStringLiteral("id")).toString(), id);
        QCOMPARE(note.value(QStringLiteral("title")).toString(), QStringLiteral("Groceries"));
        QCOMPARE(note.value(QStringLiteral("preview")).toString(), QStringLiteral("- eggs - coffee"));
        QCOMPARE(store.read(id), QStringLiteral("\nGroceries\n- eggs\n\n- coffee\n"));
    }

    void testEmptyTextDeletesNote()
    {
        QTemporaryDir dir;
        NotesStore store(dir.path());
        const QString id = store.newId();
        store.write(id, QStringLiteral("x"));
        store.write(id, QStringLiteral("  \n"));
        QCOMPARE(store.notes().size(), 0);
        QVERIFY(QDir(dir.path()).entryList(QDir::Files).isEmpty());
    }

    void testNewestFirstAndIdsAreUnique()
    {
        QTemporaryDir dir;
        NotesStore store(dir.path());
        const QString a = store.newId();
        store.write(a, QStringLiteral("old"));
        const QString b = store.newId();
        QVERIFY(a != b);
        QTest::qWait(20);
        store.write(b, QStringLiteral("new"));
        QCOMPARE(store.notes().at(0).toMap().value(QStringLiteral("title")).toString(), QStringLiteral("new"));
    }

    void testRejectsPathsOutsideFolder()
    {
        QTemporaryDir dir;
        NotesStore store(dir.path() + QStringLiteral("/notes"));
        store.write(QStringLiteral("../escape"), QStringLiteral("x"));
        QVERIFY(!QFile::exists(dir.filePath(QStringLiteral("escape.txt"))));
        QCOMPARE(store.read(QStringLiteral("../escape")), QString());
    }
};

QTEST_GUILESS_MAIN(TestNotes)
#include "tst_notes.moc"
