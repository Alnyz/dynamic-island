#include "mpriseeks.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QDBusConnectionInterface>

MprisSeeks::MprisSeeks(QObject *parent)
    : QObject(parent)
{
    QDBusConnection::sessionBus().connect(QString(), QStringLiteral("/org/mpris/MediaPlayer2"),
                                          QStringLiteral("org.mpris.MediaPlayer2.Player"),
                                          QStringLiteral("Seeked"), this, SLOT(onSeeked(qlonglong)));
}

// Properties.Get on a player, async; done gets nothing on an error.
void MprisSeeks::get(const QString &service, const QString &iface, const QString &name, std::function<void(const QVariant &)> done)
{
    auto msg = QDBusMessage::createMethodCall(service, QStringLiteral("/org/mpris/MediaPlayer2"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"),
                                              QStringLiteral("Get"));
    msg << iface << name;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [watcher, done] {
        watcher->deleteLater();
        const QDBusPendingReply<QDBusVariant> reply = *watcher;
        done(reply.isError() ? QVariant() : reply.value().variant());
    });
}

void MprisSeeks::onSeeked(qlonglong position)
{
    // The signal names the sender only by its bus address; its Identity is what QML can match.
    get(message().service(), QStringLiteral("org.mpris.MediaPlayer2"), QStringLiteral("Identity"), [this, position](const QVariant &v) {
        if (v.isValid())
            Q_EMIT seeked(v.toString(), position);
    });
}

void MprisSeeks::askPosition(const QString &identity)
{
    if (identity.isEmpty())
        return;
    const auto known = m_services.constFind(identity);
    if (known != m_services.constEnd()) {
        readPosition(identity, *known);
        return;
    }
    // Not known yet: ask every player on the bus for its Identity.
    const QStringList names = QDBusConnection::sessionBus().interface()->registeredServiceNames().value();
    for (const QString &name : names) {
        if (!name.startsWith(QLatin1String("org.mpris.MediaPlayer2.")))
            continue;
        get(name, QStringLiteral("org.mpris.MediaPlayer2"), QStringLiteral("Identity"), [this, name, identity](const QVariant &v) {
            if (v.toString() != identity || m_services.contains(identity))
                return;
            m_services.insert(identity, name);
            readPosition(identity, name);
        });
    }
}

void MprisSeeks::readPosition(const QString &identity, const QString &service)
{
    get(service, QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("Position"), [this, identity](const QVariant &v) {
        if (v.isValid())
            Q_EMIT positionRead(identity, v.toLongLong());
        else
            m_services.remove(identity);
    });
}
