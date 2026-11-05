#pragma once

#include <QHash>
#include <QObject>
#include <QStringList>
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

    // Buttons from a Notify actions list ([key, label, key, label, ...]): at most 3 {key, label},
    // without "default" (a click on the notification) and "inline-reply" (only Plasma can deliver replies).
    static QVariantList buttons(const QStringList &actions);

    Q_INVOKABLE void openApp(const QString &desktopEntry);
    // Runs one of the app's actions through Plasma's notification server, as its own popup would.
    Q_INVOKABLE void invokeAction(uint serverId, const QString &key);

Q_SIGNALS:
    // describe()'s map plus replaces, the Notify replaces_id (0 for a new notification). With actions it
    // also has serverId (Plasma's id for it), buttons and hasDefault.
    void notified(const QVariantMap &notification);

private:
    friend class TestWatchers;
    void handle(DBusMessage *message);
    void dispatch();
    void flushPending(const QString &key);

    // Notifications with actions wait for Plasma's reply, which carries their id. Key: "sender serial".
    QHash<QString, QVariantMap> m_pending;

    DBusConnection *m_conn = nullptr;
    QSocketNotifier *m_notifier = nullptr;
};
