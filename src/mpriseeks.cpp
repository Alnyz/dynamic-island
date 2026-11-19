#include "mpriseeks.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>

MprisSeeks::MprisSeeks(QObject *parent)
    : QObject(parent)
{
    QDBusConnection::sessionBus().connect(QString(), QStringLiteral("/org/mpris/MediaPlayer2"),
                                          QStringLiteral("org.mpris.MediaPlayer2.Player"),
                                          QStringLiteral("Seeked"), this, SLOT(onSeeked(qlonglong)));
}

void MprisSeeks::onSeeked(qlonglong position)
{
    // The signal names the sender only by its bus address; its Identity is what QML can match.
    const QString sender = message().service();
    auto get = QDBusMessage::createMethodCall(sender, QStringLiteral("/org/mpris/MediaPlayer2"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"),
                                              QStringLiteral("Get"));
    get << QStringLiteral("org.mpris.MediaPlayer2") << QStringLiteral("Identity");
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(get), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, position] {
        watcher->deleteLater();
        const QDBusPendingReply<QDBusVariant> reply = *watcher;
        if (!reply.isError())
            Q_EMIT seeked(reply.value().variant().toString(), position);
    });
}
