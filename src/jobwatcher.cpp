#include "jobwatcher.h"

#include <QSocketNotifier>
#include <dbus/dbus.h>

namespace
{
QVariant readBasic(DBusMessageIter *variant)
{
    switch (dbus_message_iter_get_arg_type(variant)) {
    case DBUS_TYPE_STRING: {
        const char *s = nullptr;
        dbus_message_iter_get_basic(variant, &s);
        return QString::fromUtf8(s ? s : "");
    }
    case DBUS_TYPE_BOOLEAN: {
        dbus_bool_t b = false;
        dbus_message_iter_get_basic(variant, &b);
        return bool(b);
    }
    case DBUS_TYPE_INT32: {
        dbus_int32_t v = 0;
        dbus_message_iter_get_basic(variant, &v);
        return qlonglong(v);
    }
    case DBUS_TYPE_UINT32: {
        dbus_uint32_t v = 0;
        dbus_message_iter_get_basic(variant, &v);
        return qlonglong(v);
    }
    case DBUS_TYPE_INT64: {
        dbus_int64_t v = 0;
        dbus_message_iter_get_basic(variant, &v);
        return qlonglong(v);
    }
    case DBUS_TYPE_UINT64: {
        dbus_uint64_t v = 0;
        dbus_message_iter_get_basic(variant, &v);
        return qlonglong(v);
    }
    default:
        return {};
    }
}
}

JobWatcher::JobWatcher(QObject *parent)
    : QObject(parent)
{
}

JobWatcher::~JobWatcher()
{
    close();
}

void JobWatcher::setEnabled(bool on)
{
    if (on == enabled())
        return;
    if (!on) {
        close();
        Q_EMIT enabledChanged();
        return;
    }

    DBusError err;
    dbus_error_init(&err);
    m_conn = dbus_bus_get_private(DBUS_BUS_SESSION, &err);
    if (!m_conn) {
        qWarning("JobWatcher: %s", err.message);
        dbus_error_free(&err);
        return;
    }
    dbus_connection_set_exit_on_disconnect(m_conn, false);

    DBusMessage *become = dbus_message_new_method_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus.Monitoring", "BecomeMonitor");
    const char *rules[] = {
        "type='method_call',interface='org.kde.JobViewV3',member='update'",
        "type='method_call',interface='org.kde.JobViewV3',member='terminate'",
        "type='signal',sender='org.freedesktop.DBus',member='NameOwnerChanged'",
    };
    const char **rulesPtr = rules;
    dbus_uint32_t flags = 0;
    dbus_message_append_args(become, DBUS_TYPE_ARRAY, DBUS_TYPE_STRING, &rulesPtr, 3, DBUS_TYPE_UINT32, &flags, DBUS_TYPE_INVALID);
    DBusMessage *reply = dbus_connection_send_with_reply_and_block(m_conn, become, 2000, &err);
    dbus_message_unref(become);
    if (!reply) {
        qWarning("JobWatcher: %s", err.message);
        dbus_error_free(&err);
        close();
        return;
    }
    dbus_message_unref(reply);

    dbus_connection_add_filter(
        m_conn,
        [](DBusConnection *, DBusMessage *message, void *self) {
            static_cast<JobWatcher *>(self)->handle(message);
            return DBUS_HANDLER_RESULT_HANDLED;
        },
        this, nullptr);

    int fd = -1;
    dbus_connection_get_unix_fd(m_conn, &fd);
    m_notifier = new QSocketNotifier(fd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &JobWatcher::dispatch);
    Q_EMIT enabledChanged();
    dispatch();
}

void JobWatcher::close()
{
    delete m_notifier;
    m_notifier = nullptr;
    if (m_conn) {
        dbus_connection_close(m_conn);
        dbus_connection_unref(m_conn);
        m_conn = nullptr;
    }
}

void JobWatcher::dispatch()
{
    if (!dbus_connection_read_write(m_conn, 0)) {
        m_notifier->setEnabled(false);
        return;
    }
    while (dbus_connection_dispatch(m_conn) == DBUS_DISPATCH_DATA_REMAINS) {
    }
}

QVariantMap JobWatcher::readProps(DBusMessage *update)
{
    QVariantMap props;
    DBusMessageIter it, dict;
    if (!dbus_message_iter_init(update, &it) || dbus_message_iter_get_arg_type(&it) != DBUS_TYPE_ARRAY)
        return props;
    dbus_message_iter_recurse(&it, &dict);
    while (dbus_message_iter_get_arg_type(&dict) == DBUS_TYPE_DICT_ENTRY) {
        DBusMessageIter entry, variant;
        dbus_message_iter_recurse(&dict, &entry);
        const char *key = nullptr;
        dbus_message_iter_get_basic(&entry, &key);
        dbus_message_iter_next(&entry);
        dbus_message_iter_recurse(&entry, &variant);
        const QVariant value = readBasic(&variant);
        if (value.isValid())
            props.insert(QString::fromUtf8(key), value);
        dbus_message_iter_next(&dict);
    }
    return props;
}

QString JobWatcher::key(DBusMessage *message)
{
    const char *sender = dbus_message_get_sender(message);
    const char *path = dbus_message_get_path(message);
    return QString::fromUtf8(sender ? sender : "") + QLatin1Char(' ') + QString::fromUtf8(path ? path : "");
}

void JobWatcher::handle(DBusMessage *message)
{
    if (dbus_message_is_method_call(message, "org.kde.JobViewV3", "update")) {
        Q_EMIT updated(key(message), readProps(message));
    } else if (dbus_message_is_method_call(message, "org.kde.JobViewV3", "terminate")) {
        dbus_uint32_t code = 0;
        const char *error = "";
        dbus_message_get_args(message, nullptr, DBUS_TYPE_UINT32, &code, DBUS_TYPE_STRING, &error, DBUS_TYPE_INVALID);
        Q_EMIT ended(key(message), int(code), QString::fromUtf8(error));
    } else if (dbus_message_is_signal(message, "org.freedesktop.DBus", "NameOwnerChanged")) {
        const char *name = nullptr, *oldOwner = nullptr, *newOwner = nullptr;
        if (dbus_message_get_args(message, nullptr, DBUS_TYPE_STRING, &name, DBUS_TYPE_STRING, &oldOwner, DBUS_TYPE_STRING, &newOwner, DBUS_TYPE_INVALID)
            && name[0] == ':' && newOwner[0] == '\0')
            Q_EMIT ownerGone(QString::fromUtf8(name));
    }
}
