#include "mpriseeks.h"

#include <QDBusArgument>
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

void MprisSeeks::title(const QString &service, std::function<void(const QString &)> done)
{
    get(service, QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("Metadata"), [done](const QVariant &v) {
        done(qdbus_cast<QVariantMap>(v).value(QStringLiteral("xesam:title")).toString());
    });
}

void MprisSeeks::onSeeked(qlonglong position)
{
    // The signal names the sender only by its bus address; its Identity and song are what QML can match.
    const QString service = message().service();
    get(service, QStringLiteral("org.mpris.MediaPlayer2"), QStringLiteral("Identity"), [this, service, position](const QVariant &v) {
        if (!v.isValid())
            return;
        const QString identity = v.toString();
        title(service, [this, identity, position](const QString &song) {
            Q_EMIT seeked(identity, song, position);
        });
    });
}

void MprisSeeks::askPosition(const QString &identity, const QString &song)
{
    if (identity.isEmpty())
        return;
    const QString key = identity + QLatin1Char('\n') + song;
    const auto known = m_services.constFind(key);
    if (known != m_services.constEnd()) {
        readPosition(identity, song, *known);
        return;
    }
    // Not known yet: ask every player on the bus for its Identity, then its song.
    const QStringList names = QDBusConnection::sessionBus().interface()->registeredServiceNames().value();
    for (const QString &name : names) {
        if (!name.startsWith(QLatin1String("org.mpris.MediaPlayer2.")))
            continue;
        get(name, QStringLiteral("org.mpris.MediaPlayer2"), QStringLiteral("Identity"), [this, name, identity, song, key](const QVariant &v) {
            if (v.toString() != identity)
                return;
            title(name, [this, name, identity, song, key](const QString &found) {
                if (found != song || m_services.contains(key))
                    return;
                m_services.insert(key, name);
                readPosition(identity, song, name);
            });
        });
    }
}

void MprisSeeks::readPosition(const QString &identity, const QString &song, const QString &service)
{
    // The song is read again: a player found earlier may have moved on.
    title(service, [this, identity, song, service](const QString &now) {
        if (now != song) {
            m_services.remove(identity + QLatin1Char('\n') + song);
            return;
        }
        get(service, QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("Position"), [this, identity, song](const QVariant &v) {
            if (v.isValid())
                Q_EMIT positionRead(identity, song, v.toLongLong());
            else
                m_services.remove(identity + QLatin1Char('\n') + song);
        });
    });
}
