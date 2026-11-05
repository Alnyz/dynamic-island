#pragma once

#include <QObject>
#include <QVariantList>
#include <qqmlintegration.h>

class QMimeData;

// Our own copy history: Plasma's Klipper history isn't reachable from other apps.
// Stored as history.json (0600) plus one PNG per copied image.
class ClipboardHistory : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    explicit ClipboardHistory(QObject *parent = nullptr);
    ClipboardHistory(const QString &directory, bool watchSystem, QObject *parent = nullptr);

    QVariantList items() const { return m_items; }

    void handleMime(const QMimeData *mime);

    Q_INVOKABLE void copy(const QString &id);
    Q_INVOKABLE void copyText(const QString &text);
    Q_INVOKABLE void pin(const QString &id, bool on);
    Q_INVOKABLE void remove(const QString &id);
    // Undoable removal: take() drops the item from the list but keeps its image file and returns
    // {item, index}; restore() puts it back, discard() deletes the file once undo is no longer offered.
    Q_INVOKABLE QVariantMap take(const QString &id);
    Q_INVOKABLE void restore(const QVariantMap &taken);
    Q_INVOKABLE void discard(const QVariantMap &taken);
    // Removes everything except pinned items.
    Q_INVOKABLE void clear();

    static constexpr int kMaxUnpinned = 50;

Q_SIGNALS:
    void itemsChanged();

private:
    int indexOf(const QString &id) const;
    void prepend(QVariantMap item, const QString &matchKey, const QString &matchValue);
    void dropFiles(const QVariantMap &item);
    void load();
    // Image files no item points at, left by a take() that was never restored or discarded.
    void dropOrphans();
    void save();

    QString m_dir;
    bool m_watch;
    QVariantList m_items;
};
