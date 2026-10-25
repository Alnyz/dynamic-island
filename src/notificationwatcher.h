#pragma once

#include <QObject>
#include <QVariantMap>
#include <qqmlintegration.h>

class QSocketNotifier;
struct DBusConnection;
struct DBusMessage;

// Watches Notify calls on the session bus without taking over Plasma's notification server.
// A D-Bus monitor connection must never send, which QtDBus can't promise, so this uses libdbus.
class NotificationWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit NotificationWatcher(QObject *parent = nullptr);
    ~NotificationWatcher() override;

    // {app, desktopEntry, icon, title, body}; empty when there's nothing worth showing.
    static QVariantMap describe(const QString &appName, const QString &appIcon, const QString &summary, const QString &body, const QVariantMap &hints);

    Q_INVOKABLE void openApp(const QString &desktopEntry);

Q_SIGNALS:
    // describe()'s map plus replaces, the Notify replaces_id (0 for a new notification).
    void notified(const QVariantMap &notification);

private:
    friend class TestWatchers;
    void handle(DBusMessage *message);
    void dispatch();

    DBusConnection *m_conn = nullptr;
    QSocketNotifier *m_notifier = nullptr;
};
