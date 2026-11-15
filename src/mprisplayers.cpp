#include "mprisplayers.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QDateTime>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>

namespace
{
const QString kPrefix = QStringLiteral("org.mpris.MediaPlayer2.");
const QString kPath = QStringLiteral("/org/mpris/MediaPlayer2");
const QString kRoot = QStringLiteral("org.mpris.MediaPlayer2");
const QString kPlayer = QStringLiteral("org.mpris.MediaPlayer2.Player");
const QString kProps = QStringLiteral("org.freedesktop.DBus.Properties");

QString iconFor(const QString &desktopEntry)
{
    if (desktopEntry.isEmpty())
        return {};
    const QString file = QStandardPaths::locate(QStandardPaths::ApplicationsLocation, desktopEntry + QStringLiteral(".desktop"));
    if (file.isEmpty())
        return desktopEntry;
    QSettings desktop(file, QSettings::IniFormat);
    desktop.beginGroup(QStringLiteral("Desktop Entry"));
    return desktop.value(QStringLiteral("Icon"), desktopEntry).toString();
}

QString joined(const QVariant &v)
{
    return v.canConvert<QStringList>() ? v.toStringList().join(QStringLiteral(", ")) : v.toString();
}

// D-Bus a{sv} values arrive wrapped; unwrap nested variants and maps.
QVariantMap toMap(const QVariant &v)
{
    if (v.userType() == qMetaTypeId<QDBusArgument>()) {
        QVariantMap map;
        v.value<QDBusArgument>() >> map;
        return map;
    }
    return v.toMap();
}
}

MprisPlayer::MprisPlayer(const QString &service, QObject *parent)
    : QObject(parent)
    , m_service(service)
    , m_tick(new QTimer(this))
{
    setObjectName(service.mid(kPrefix.size()));
    m_tick->setInterval(1000);
    connect(m_tick, &QTimer::timeout, this, &MprisPlayer::positionChanged);

    auto bus = QDBusConnection::sessionBus();
    bus.connect(service, kPath, kProps, QStringLiteral("PropertiesChanged"), this,
                SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
    bus.connect(service, kPath, kPlayer, QStringLiteral("Seeked"), this, SLOT(onSeeked(qlonglong)));
    fetchAll();
}

void MprisPlayer::fetchAll()
{
    for (const QString &iface : {kRoot, kPlayer}) {
        QDBusMessage msg = QDBusMessage::createMethodCall(m_service, kPath, kProps, QStringLiteral("GetAll"));
        msg << iface;
        auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
        connect(w, &QDBusPendingCallWatcher::finished, this, [this, iface](QDBusPendingCallWatcher *w) {
            w->deleteLater();
            QDBusPendingReply<QVariantMap> reply = *w;
            if (!reply.isError())
                apply(iface, reply.value());
        });
    }
}

void MprisPlayer::onPropertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &invalidated)
{
    apply(iface, changed);
    // Some players only say a property changed; fetch them again.
    if (!invalidated.isEmpty())
        fetchAll();
}

void MprisPlayer::onSeeked(qlonglong position)
{
    setRawPosition(double(position));
}

void MprisPlayer::apply(const QString &iface, const QVariantMap &props)
{
    if (iface == kRoot) {
        if (props.contains(QStringLiteral("Identity"))) {
            m_identity = props.value(QStringLiteral("Identity")).toString();
            Q_EMIT identityChanged();
        }
        if (props.contains(QStringLiteral("DesktopEntry"))) {
            m_desktopEntry = props.value(QStringLiteral("DesktopEntry")).toString();
            m_iconName = iconFor(m_desktopEntry);
            Q_EMIT desktopEntryChanged();
        }
        if (props.contains(QStringLiteral("CanRaise"))) {
            m_canRaise = props.value(QStringLiteral("CanRaise")).toBool();
            Q_EMIT capsChanged();
        }
        return;
    }
    if (iface != kPlayer)
        return;

    if (props.contains(QStringLiteral("Metadata")))
        applyMetadata(toMap(props.value(QStringLiteral("Metadata"))));
    if (props.contains(QStringLiteral("Rate")))
        m_rate = props.value(QStringLiteral("Rate")).toDouble();
    if (props.contains(QStringLiteral("PlaybackStatus"))) {
        const double now = position();
        const QString s = props.value(QStringLiteral("PlaybackStatus")).toString();
        const int status = s == QLatin1String("Playing") ? Playing : s == QLatin1String("Paused") ? Paused : s == QLatin1String("Stopped") ? Stopped : Unknown;
        if (status != m_status) {
            m_status = status;
            m_position = now;
            m_positionAt = QDateTime::currentMSecsSinceEpoch();
            if (m_status == Playing)
                m_tick->start();
            else
                m_tick->stop();
            Q_EMIT playbackStatusChanged();
            updatePosition();
        }
    }
    if (props.contains(QStringLiteral("Position")))
        setRawPosition(props.value(QStringLiteral("Position")).toDouble());
    if (props.contains(QStringLiteral("LoopStatus"))) {
        const QString s = props.value(QStringLiteral("LoopStatus")).toString();
        m_loop = s == QLatin1String("None") ? 1 : s == QLatin1String("Playlist") ? 2 : s == QLatin1String("Track") ? 3 : 0;
        Q_EMIT loopStatusChanged();
    }
    if (props.contains(QStringLiteral("Shuffle"))) {
        m_shuffle = props.value(QStringLiteral("Shuffle")).toBool() ? 2 : 1;
        Q_EMIT shuffleChanged();
    }
    if (props.contains(QStringLiteral("Volume"))) {
        m_volume = props.value(QStringLiteral("Volume")).toDouble();
        Q_EMIT volumeChanged();
    }
    bool caps = false;
    auto cap = [&](const char *name, bool &field) {
        const QString key = QString::fromLatin1(name);
        if (props.contains(key)) {
            field = props.value(key).toBool();
            caps = true;
        }
    };
    cap("CanSeek", m_canSeek);
    cap("CanGoNext", m_canGoNext);
    cap("CanGoPrevious", m_canGoPrevious);
    cap("CanPlay", m_canPlay);
    cap("CanPause", m_canPause);
    cap("CanControl", m_canControl);
    if (caps)
        Q_EMIT capsChanged();
}

void MprisPlayer::applyMetadata(const QVariantMap &meta)
{
    auto update = [](QString &field, const QString &value, void (MprisPlayer::*signal)(), MprisPlayer *self) {
        if (field != value) {
            field = value;
            Q_EMIT(self->*signal)();
        }
    };
    const QVariant id = meta.value(QStringLiteral("mpris:trackid"));
    const QString trackId = id.canConvert<QDBusObjectPath>() ? id.value<QDBusObjectPath>().path() : id.toString();
    m_trackId = trackId;
    update(m_track, meta.value(QStringLiteral("xesam:title")).toString(), &MprisPlayer::trackChanged, this);
    update(m_artist, joined(meta.value(QStringLiteral("xesam:artist"))), &MprisPlayer::artistChanged, this);
    update(m_album, meta.value(QStringLiteral("xesam:album")).toString(), &MprisPlayer::albumChanged, this);
    update(m_artUrl, meta.value(QStringLiteral("mpris:artUrl")).toString(), &MprisPlayer::artUrlChanged, this);
    const double length = meta.value(QStringLiteral("mpris:length")).toDouble();
    if (length != m_length) {
        m_length = length;
        Q_EMIT lengthChanged();
    }
}

double MprisPlayer::position() const
{
    if (m_status != Playing)
        return m_position;
    const double elapsed = double(QDateTime::currentMSecsSinceEpoch() - m_positionAt) * 1000.0 * m_rate;
    const double p = m_position + elapsed;
    return m_length > 0 ? qMin(p, m_length) : p;
}

void MprisPlayer::setRawPosition(double us)
{
    m_position = us;
    m_positionAt = QDateTime::currentMSecsSinceEpoch();
    Q_EMIT positionChanged();
}

void MprisPlayer::setPosition(double us)
{
    if (m_trackId.isEmpty()) {
        Seek(us - position());
    } else {
        call(QStringLiteral("SetPosition"), {QVariant::fromValue(QDBusObjectPath(m_trackId)), qlonglong(us)});
    }
    setRawPosition(us);
}

void MprisPlayer::updatePosition()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, kPath, kProps, QStringLiteral("Get"));
    msg << kPlayer << QStringLiteral("Position");
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QDBusVariant> reply = *w;
        if (!reply.isError())
            setRawPosition(reply.value().variant().toDouble());
    });
}

void MprisPlayer::setProp(const QString &name, const QVariant &value)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, kPath, kProps, QStringLiteral("Set"));
    msg << kPlayer << name << QVariant::fromValue(QDBusVariant(value));
    QDBusConnection::sessionBus().asyncCall(msg);
}

void MprisPlayer::setLoopStatus(int status)
{
    static const char *names[] = {"None", "None", "Playlist", "Track"};
    if (status < 1 || status > 3)
        return;
    setProp(QStringLiteral("LoopStatus"), QString::fromLatin1(names[status]));
}

void MprisPlayer::setShuffle(int value)
{
    setProp(QStringLiteral("Shuffle"), value == 2);
}

void MprisPlayer::setVolume(double v)
{
    setProp(QStringLiteral("Volume"), v);
    m_volume = v;
    Q_EMIT volumeChanged();
}

void MprisPlayer::call(const QString &method, const QVariantList &args)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, kPath, kPlayer, method);
    msg.setArguments(args);
    QDBusConnection::sessionBus().asyncCall(msg);
}

void MprisPlayer::PlayPause() { call(QStringLiteral("PlayPause")); }
void MprisPlayer::Play() { call(QStringLiteral("Play")); }
void MprisPlayer::Pause() { call(QStringLiteral("Pause")); }
void MprisPlayer::Stop() { call(QStringLiteral("Stop")); }
void MprisPlayer::Next() { call(QStringLiteral("Next")); }
void MprisPlayer::Previous() { call(QStringLiteral("Previous")); }
void MprisPlayer::Seek(double offsetUs) { call(QStringLiteral("Seek"), {qlonglong(offsetUs)}); }

void MprisPlayer::Raise()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, kPath, kRoot, QStringLiteral("Raise"));
    QDBusConnection::sessionBus().asyncCall(msg);
}

MprisPlayers::MprisPlayers(QObject *parent)
    : QObject(parent)
{
    auto bus = QDBusConnection::sessionBus();
    bus.connect(QStringLiteral("org.freedesktop.DBus"), QStringLiteral("/org/freedesktop/DBus"), QStringLiteral("org.freedesktop.DBus"),
                QStringLiteral("NameOwnerChanged"), this, SLOT(onOwnerChanged(QString, QString, QString)));
    const QStringList names = bus.interface()->registeredServiceNames().value();
    for (const QString &name : names) {
        if (name.startsWith(kPrefix))
            add(name);
    }
}

QVariantList MprisPlayers::list() const
{
    QVariantList out;
    for (MprisPlayer *p : m_players)
        out << QVariant::fromValue(static_cast<QObject *>(p));
    return out;
}

void MprisPlayers::onOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner)
{
    if (!name.startsWith(kPrefix))
        return;
    if (!oldOwner.isEmpty())
        remove(name);
    if (!newOwner.isEmpty())
        add(name);
}

void MprisPlayers::add(const QString &service)
{
    for (MprisPlayer *p : m_players) {
        if (p->service() == service)
            return;
    }
    m_players << new MprisPlayer(service, this);
    Q_EMIT listChanged();
}

void MprisPlayers::remove(const QString &service)
{
    for (int i = 0; i < m_players.size(); ++i) {
        if (m_players[i]->service() == service) {
            m_players.takeAt(i)->deleteLater();
            Q_EMIT listChanged();
            return;
        }
    }
}
