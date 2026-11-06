#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlintegration.h>

// The To-Do list, kept in ~/.local/share/dynamic-island/todo.json in the order tasks were added.
class TodoStore : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // [{id, text, done, created (ms)}]
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)
    // The first task not yet done, or an empty map: what the idle pill shows.
    Q_PROPERTY(QVariantMap nextOpen READ nextOpen NOTIFY itemsChanged)
    Q_PROPERTY(int openCount READ openCount NOTIFY itemsChanged)

public:
    explicit TodoStore(QObject *parent = nullptr);
    explicit TodoStore(const QString &file, QObject *parent = nullptr);

    QVariantList items() const { return m_items; }
    QVariantMap nextOpen() const;
    int openCount() const;

    // Blank text adds nothing and returns an empty id.
    Q_INVOKABLE QString add(const QString &text);
    Q_INVOKABLE void setDone(const QString &id, bool done);
    // {item, index} of the removed task, for undo; empty when there was none.
    Q_INVOKABLE QVariantMap remove(const QString &id);
    // Puts a removed task back where it was.
    Q_INVOKABLE void restore(const QVariantMap &removed);
    Q_INVOKABLE void clearDone();
    // Tasks from the first To-Do version, kept as JSON ([{text, done}]) in QSettings; returns how many.
    Q_INVOKABLE int importJson(const QString &json);
    // Moves the first version's list over once: it sat in QSettings' default file, which (with no
    // organisation name set) is ~/.config/Unknown Organization/dynamic-island.conf. Only an empty
    // store takes it; the old entry is removed either way. Returns how many tasks came over.
    Q_INVOKABLE int importLegacy(const QString &path = QString());
    static QString legacyPath();

Q_SIGNALS:
    void itemsChanged();

private:
    void load();
    void save();
    QString newId() const;
    int indexOf(const QString &id) const;

    QString m_file;
    QVariantList m_items;
};
