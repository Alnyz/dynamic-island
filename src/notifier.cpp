#include "notifier.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QVariantMap>

void Notifier::timerDone()
{
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Notifications"),
                                              QStringLiteral("/org/freedesktop/Notifications"),
                                              QStringLiteral("org.freedesktop.Notifications"),
                                              QStringLiteral("Notify"));
    const QVariantMap hints{
        {QStringLiteral("urgency"), QVariant::fromValue<uchar>(2)},
        {QStringLiteral("sound-name"), QStringLiteral("alarm-clock-elapsed")},
        {QStringLiteral("desktop-entry"), QStringLiteral("dynamic-island")},
    };
    msg << QStringLiteral("Dynamic Island") << 0u << QStringLiteral("chronometer") << QStringLiteral("Timer done")
        << QString() << QStringList() << hints << -1;
    QDBusConnection::sessionBus().send(msg);
}
