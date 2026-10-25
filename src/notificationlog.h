#pragma once

#include <QObject>
#include <QVariantList>
#include <qqmlintegration.h>

// The saved notification history, one JSON array in ~/.local/share/dynamic-island/notifications.json.
// The rules (what is kept, for how long) live in logic.js; this only reads and writes the file.
class NotificationLog : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    explicit NotificationLog(QObject *parent = nullptr);
    explicit NotificationLog(const QString &file, QObject *parent = nullptr);

    QVariantList items() const { return m_items; }

    Q_INVOKABLE void save(const QVariantList &items);

Q_SIGNALS:
    void itemsChanged();

private:
    QString m_file;
    QVariantList m_items;
};
