#include "notificationwatcher.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QProcess>
#include <QTimer>
#include <QRegularExpression>
#include <QSocketNotifier>
#include <QTextDocumentFragment>
#include <dbus/dbus.h>

namespace
{
QString readString(DBusMessageIter *it)
{
    const char *s = nullptr;
    if (dbus_message_iter_get_arg_type(it) == DBUS_TYPE_STRING)
        dbus_message_iter_get_basic(it, &s);
    dbus_message_iter_next(it);
    return QString::fromUtf8(s ? s : "");
}

// String hints (desktop-entry, image-path) and byte ones (urgency) are kept; image-data is skipped.
QVariantMap readHints(DBusMessageIter *it)
{
    QVariantMap hints;
    if (dbus_message_iter_get_arg_type(it) != DBUS_TYPE_ARRAY)
        return hints;
    DBusMessageIter dict;
    dbus_message_iter_recurse(it, &dict);
    while (dbus_message_iter_get_arg_type(&dict) == DBUS_TYPE_DICT_ENTRY) {
        DBusMessageIter entry, variant;
        dbus_message_iter_recurse(&dict, &entry);
        const QString key = readString(&entry);
        dbus_message_iter_recurse(&entry, &variant);
        if (dbus_message_iter_get_arg_type(&variant) == DBUS_TYPE_STRING) {
            const char *v = nullptr;
            dbus_message_iter_get_basic(&variant, &v);
            hints.insert(key, QString::fromUtf8(v));
        } else if (dbus_message_iter_get_arg_type(&variant) == DBUS_TYPE_BYTE) {
            unsigned char v = 0;
            dbus_message_iter_get_basic(&variant, &v);
            hints.insert(key, int(v));
        }
        dbus_message_iter_next(&dict);
    }
    return hints;
}

QStringList readStringList(DBusMessageIter *it)
{
    QStringList list;
    if (dbus_message_iter_get_arg_type(it) == DBUS_TYPE_ARRAY) {
        DBusMessageIter items;
        dbus_message_iter_recurse(it, &items);
        while (dbus_message_iter_get_arg_type(&items) == DBUS_TYPE_STRING)
            list << readString(&items);
    }
    dbus_message_iter_next(it);
    return list;
}

// How long a notification with actions waits for Plasma's reply before it shows without buttons.
constexpr int kReplyWaitMs = 300;

}

NotificationWatcher::NotificationWatcher(QObject *parent)
    : QObject(parent)
{
    DBusError err;
    dbus_error_init(&err);
    m_conn = dbus_bus_get_private(DBUS_BUS_SESSION, &err);
    if (!m_conn) {
        qWarning("NotificationWatcher: %s", err.message);
        dbus_error_free(&err);
        return;
    }
    dbus_connection_set_exit_on_disconnect(m_conn, false);

    DBusMessage *become = dbus_message_new_method_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus.Monitoring", "BecomeMonitor");
    // Plasma's replies to Notify carry the id that its actions are invoked by.
    const char *ruleList[] = {"type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
                              "type='method_return',sender='org.freedesktop.Notifications'"};
    const char **rules = ruleList;
    dbus_uint32_t flags = 0;
    dbus_message_append_args(become, DBUS_TYPE_ARRAY, DBUS_TYPE_STRING, &rules, 2, DBUS_TYPE_UINT32, &flags, DBUS_TYPE_INVALID);
    DBusMessage *reply = dbus_connection_send_with_reply_and_block(m_conn, become, 2000, &err);
    dbus_message_unref(become);
    if (!reply) {
        qWarning("NotificationWatcher: %s", err.message);
        dbus_error_free(&err);
        return;
    }
    dbus_message_unref(reply);

    dbus_connection_add_filter(
        m_conn,
        [](DBusConnection *, DBusMessage *message, void *self) {
            static_cast<NotificationWatcher *>(self)->handle(message);
            return DBUS_HANDLER_RESULT_HANDLED;
        },
        this, nullptr);

    int fd = -1;
    dbus_connection_get_unix_fd(m_conn, &fd);
    m_notifier = new QSocketNotifier(fd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &NotificationWatcher::dispatch);
    dispatch();
}

NotificationWatcher::~NotificationWatcher()
{
    if (m_conn) {
        dbus_connection_close(m_conn);
        dbus_connection_unref(m_conn);
    }
}

void NotificationWatcher::dispatch()
{
    if (!dbus_connection_read_write(m_conn, 0)) {
        m_notifier->setEnabled(false);
        return;
    }
    while (dbus_connection_dispatch(m_conn) == DBUS_DISPATCH_DATA_REMAINS) {
    }
}

void NotificationWatcher::handle(DBusMessage *message)
{
    if (dbus_message_get_type(message) == DBUS_MESSAGE_TYPE_METHOD_RETURN) {
        const char *to = dbus_message_get_destination(message);
        const QString key = QString::fromUtf8(to ? to : "") + QLatin1Char(' ') + QString::number(dbus_message_get_reply_serial(message));
        if (!m_pending.contains(key))
            return;
        dbus_uint32_t id = 0;
        DBusMessageIter it;
        if (dbus_message_iter_init(message, &it) && dbus_message_iter_get_arg_type(&it) == DBUS_TYPE_UINT32)
            dbus_message_iter_get_basic(&it, &id);
        if (id > 0)
            m_pending[key].insert(QStringLiteral("serverId"), static_cast<uint>(id));
        flushPending(key);
        return;
    }
    if (!dbus_message_is_method_call(message, "org.freedesktop.Notifications", "Notify"))
        return;
    DBusMessageIter it;
    if (!dbus_message_iter_init(message, &it))
        return;
    const QString appName = readString(&it);
    dbus_uint32_t replaces = 0;
    if (dbus_message_iter_get_arg_type(&it) == DBUS_TYPE_UINT32)
        dbus_message_iter_get_basic(&it, &replaces);
    dbus_message_iter_next(&it);
    const QString appIcon = readString(&it);
    const QString summary = readString(&it);
    const QString body = readString(&it);
    const QStringList actions = readStringList(&it);
    const QVariantMap hints = readHints(&it);
    QVariantMap n = describe(appName, appIcon, summary, body, hints);
    if (n.isEmpty())
        return;
    n.insert(QStringLiteral("replaces"), static_cast<int>(replaces));
    const QVariantList shown = buttons(actions);
    const bool hasDefault = actions.size() >= 2 && actions.indexOf(QStringLiteral("default")) % 2 == 0;
    if (shown.isEmpty() && !hasDefault) {
        Q_EMIT notified(n);
        return;
    }
    n.insert(QStringLiteral("buttons"), shown);
    n.insert(QStringLiteral("hasDefault"), hasDefault);
    const char *from = dbus_message_get_sender(message);
    const QString key = QString::fromUtf8(from ? from : "") + QLatin1Char(' ') + QString::number(dbus_message_get_serial(message));
    m_pending.insert(key, n);
    QTimer::singleShot(kReplyWaitMs, this, [this, key] { flushPending(key); });
}

void NotificationWatcher::flushPending(const QString &key)
{
    if (!m_pending.contains(key))
        return;
    QVariantMap n = m_pending.take(key);
    // Without an id the actions can't be run, so it shows as a plain notification.
    if (!n.contains(QStringLiteral("serverId"))) {
        n.remove(QStringLiteral("buttons"));
        n.remove(QStringLiteral("hasDefault"));
    }
    Q_EMIT notified(n);
}

QVariantList NotificationWatcher::buttons(const QStringList &actions)
{
    QVariantList out;
    for (int i = 0; i + 1 < actions.size() && out.size() < 3; i += 2) {
        const QString key = actions.at(i);
        const QString label = actions.at(i + 1).trimmed();
        if (key == QLatin1String("default") || key == QLatin1String("inline-reply") || label.isEmpty())
            continue;
        out.append(QVariantMap{{QStringLiteral("key"), key}, {QStringLiteral("label"), label}});
    }
    return out;
}

void NotificationWatcher::invokeAction(uint serverId, const QString &key)
{
    if (serverId == 0 || key.isEmpty())
        return;
    auto call = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
                                               QStringLiteral("org.kde.NotificationManager"), QStringLiteral("InvokeAction"));
    call << serverId << key;
    QDBusConnection::sessionBus().asyncCall(call);
}

QVariantMap NotificationWatcher::describe(const QString &appName, const QString &appIcon, const QString &summary, const QString &body, const QVariantMap &hints)
{
    const QString title = summary.trimmed();
    // Bodies may carry simple HTML; the island shows one plain line.
    const QString text = QTextDocumentFragment::fromHtml(body).toPlainText().simplified();
    if (title.isEmpty() && text.isEmpty())
        return {};
    const QString entry = hints.value(QStringLiteral("desktop-entry")).toString();
    const QString imagePath = hints.value(QStringLiteral("image-path")).toString();
    QString icon = !appIcon.isEmpty() ? appIcon : !entry.isEmpty() ? entry : imagePath;
    if (icon.startsWith(QLatin1Char('/')))
        icon = QStringLiteral("file://") + icon;
    return {
        {QStringLiteral("app"), appName},
        {QStringLiteral("desktopEntry"), entry},
        {QStringLiteral("icon"), icon},
        {QStringLiteral("title"), title.isEmpty() ? appName : title},
        {QStringLiteral("body"), text},
        {QStringLiteral("urgency"), hints.value(QStringLiteral("urgency"), 1).toInt()},
    };
}

void NotificationWatcher::openApp(const QString &desktopEntry)
{
    static const QRegularExpression safe(QStringLiteral("^[\\w.-]+$"));
    if (safe.match(desktopEntry).hasMatch())
        QProcess::startDetached(QStringLiteral("gtk-launch"), {desktopEntry});
}
