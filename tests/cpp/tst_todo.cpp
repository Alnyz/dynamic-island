#include "todostore.h"

#include <QFile>
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class TestTodo : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void addKeepsOrderAndSaves()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("todo.json"));
        {
            TodoStore store(path);
            QSignalSpy changed(&store, &TodoStore::itemsChanged);
            QVERIFY(!store.add(QStringLiteral("  Buy   milk ")).isEmpty());
            store.add(QStringLiteral("Call mum"));
            QCOMPARE(changed.count(), 2);
            QVERIFY(store.add(QStringLiteral("   ")).isEmpty());
            QCOMPARE(store.items().size(), 2);
        }
        // A fresh store reads the same list back.
        TodoStore again(path);
        QCOMPARE(again.items().size(), 2);
        QCOMPARE(again.items().at(0).toMap().value(QStringLiteral("text")).toString(), QStringLiteral("Buy milk"));
        QCOMPARE(again.items().at(1).toMap().value(QStringLiteral("text")).toString(), QStringLiteral("Call mum"));
    }

    void nextOpenSkipsDone()
    {
        QTemporaryDir dir;
        TodoStore store(dir.filePath(QStringLiteral("todo.json")));
        QVERIFY(store.nextOpen().isEmpty());
        const QString a = store.add(QStringLiteral("a"));
        const QString b = store.add(QStringLiteral("b"));
        QCOMPARE(store.nextOpen().value(QStringLiteral("id")).toString(), a);
        QCOMPARE(store.openCount(), 2);
        store.setDone(a, true);
        QCOMPARE(store.nextOpen().value(QStringLiteral("id")).toString(), b);
        QCOMPARE(store.openCount(), 1);
        store.setDone(b, true);
        QVERIFY(store.nextOpen().isEmpty());
        store.setDone(a, false);
        QCOMPARE(store.nextOpen().value(QStringLiteral("id")).toString(), a);
    }

    void removeAndRestoreInPlace()
    {
        QTemporaryDir dir;
        TodoStore store(dir.filePath(QStringLiteral("todo.json")));
        store.add(QStringLiteral("a"));
        const QString b = store.add(QStringLiteral("b"));
        store.add(QStringLiteral("c"));
        const QVariantMap removed = store.remove(b);
        QCOMPARE(removed.value(QStringLiteral("index")).toInt(), 1);
        QCOMPARE(store.items().size(), 2);
        QVERIFY(store.remove(QStringLiteral("missing")).isEmpty());
        store.restore(removed);
        QCOMPARE(store.items().size(), 3);
        QCOMPARE(store.items().at(1).toMap().value(QStringLiteral("id")).toString(), b);
        // Restoring twice doesn't duplicate it.
        store.restore(removed);
        QCOMPARE(store.items().size(), 3);
    }

    void clearDoneRemovesOnlyDone()
    {
        QTemporaryDir dir;
        TodoStore store(dir.filePath(QStringLiteral("todo.json")));
        const QString a = store.add(QStringLiteral("a"));
        store.add(QStringLiteral("b"));
        store.setDone(a, true);
        store.clearDone();
        QCOMPARE(store.items().size(), 1);
        QCOMPARE(store.items().at(0).toMap().value(QStringLiteral("text")).toString(), QStringLiteral("b"));
    }

    void importsTheOldList()
    {
        QTemporaryDir dir;
        TodoStore store(dir.filePath(QStringLiteral("todo.json")));
        QCOMPARE(store.importJson(QStringLiteral(R"([{"text":"old one","done":false},{"text":"","done":false},{"text":"done one","done":true}])")), 2);
        QCOMPARE(store.items().size(), 2);
        QCOMPARE(store.items().at(1).toMap().value(QStringLiteral("done")).toBool(), true);
        QVERIFY(store.items().at(0).toMap().value(QStringLiteral("id")) != store.items().at(1).toMap().value(QStringLiteral("id")));
        QCOMPARE(store.importJson(QStringLiteral("not json")), 0);
    }

    void importsTheLegacyFileOnce()
    {
        QTemporaryDir dir;
        const QString legacy = dir.filePath(QStringLiteral("old.conf"));
        {
            QSettings old(legacy, QSettings::IniFormat);
            old.setValue(QStringLiteral("TodoList/tasksJson"), QStringLiteral(R"([{"text":"from before","done":false}])"));
            old.setValue(QStringLiteral("Other/keep"), 1);
        }
        TodoStore store(dir.filePath(QStringLiteral("todo.json")));
        QCOMPARE(store.importLegacy(legacy), 1);
        QCOMPARE(store.items().at(0).toMap().value(QStringLiteral("text")).toString(), QStringLiteral("from before"));
        // The old entry is gone, so it never comes over twice; other keys stay.
        QCOMPARE(store.importLegacy(legacy), 0);
        QCOMPARE(store.items().size(), 1);
        QSettings old(legacy, QSettings::IniFormat);
        QVERIFY(!old.contains(QStringLiteral("TodoList/tasksJson")));
        QCOMPARE(old.value(QStringLiteral("Other/keep")).toInt(), 1);
    }

    void legacyImportLeavesAFullStoreAndMissingFilesAlone()
    {
        QTemporaryDir dir;
        TodoStore store(dir.filePath(QStringLiteral("todo.json")));
        const QString missing = dir.filePath(QStringLiteral("nope/old.conf"));
        QCOMPARE(store.importLegacy(missing), 0);
        QVERIFY(!QFile::exists(missing));
        store.add(QStringLiteral("current"));
        const QString legacy = dir.filePath(QStringLiteral("old.conf"));
        {
            QSettings old(legacy, QSettings::IniFormat);
            old.setValue(QStringLiteral("TodoList/tasksJson"), QStringLiteral(R"([{"text":"stale","done":false}])"));
        }
        QCOMPARE(store.importLegacy(legacy), 0);
        QCOMPARE(store.items().size(), 1);
    }

    void brokenFileIsAnEmptyList()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("todo.json"));
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("{oops");
        f.close();
        TodoStore store(path);
        QCOMPARE(store.items().size(), 0);
    }
};

QTEST_MAIN(TestTodo)
#include "tst_todo.moc"
