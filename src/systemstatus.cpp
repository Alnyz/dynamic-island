#include "systemstatus.h"

#include <QColor>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusVariant>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>

namespace
{
const QString kSink = QStringLiteral("@DEFAULT_AUDIO_SINK@");
const QString kBattery = QStringLiteral("/sys/class/power_supply/BAT0/");
// PolicyAgent inhibition type for screen dimming/locking.
constexpr uint kChangeScreenSettings = 4;

QString readFile(const QString &path)
{
    QFile f(path);
    return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()) : QString();
}

QDBusMessage notifyCall(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
                                          QStringLiteral("org.freedesktop.Notifications"), method);
}

QDBusMessage screenSaverCall(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("/ScreenSaver"),
                                          QStringLiteral("org.freedesktop.ScreenSaver"), method);
}

// Plain messages skip QDBusInterface's introspection round trip; reads never block the UI.
void callAsync(QObject *context, const QDBusMessage &msg, std::function<void(const QDBusMessage &)> done)
{
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg, 2000), context);
    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, context, [watcher, done] {
        done(watcher->reply());
        watcher->deleteLater();
    });
}

uint callForCookie(const QDBusMessage &msg)
{
    const QDBusReply<uint> reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 2000);
    return reply.isValid() ? reply.value() : 0;
}
}

SystemStatus::SystemStatus(QObject *parent)
    : QObject(parent)
{
    refresh();
    QDBusConnection::sessionBus().connect(QStringLiteral("org.kde.ScreenBrightness"), QStringLiteral("/org/kde/ScreenBrightness"),
                                          QStringLiteral("org.kde.ScreenBrightness"), QStringLiteral("BrightnessChanged"), this,
                                          SLOT(onBrightnessChanged(QString, int, QString, QString)));
}

void SystemStatus::onBrightnessChanged(const QString &display, int value, const QString &, const QString &)
{
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.kde.ScreenBrightness"), QStringLiteral("/org/kde/ScreenBrightness/") + display,
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.kde.ScreenBrightness.Display") << QStringLiteral("MaxBrightness");
    const QDBusReply<QDBusVariant> max = QDBusConnection::sessionBus().call(get);
    const int top = max.isValid() ? max.value().variant().toInt() : 0;
    if (top > 0)
        Q_EMIT brightnessChanged(qRound(value * 100.0 / top));
}

SystemStatus::~SystemStatus()
{
    if (m_dndCookie)
        QDBusConnection::sessionBus().send(notifyCall(QStringLiteral("UnInhibit")) << m_dndCookie);
    if (m_awakeCookie)
        QDBusConnection::sessionBus().send(screenSaverCall(QStringLiteral("UnInhibit")) << m_awakeCookie);
}

std::optional<std::pair<int, bool>> SystemStatus::parseWpctlVolume(const QString &output)
{
    static const QRegularExpression re(QStringLiteral("^Volume:\\s+([0-9.]+)(\\s+\\[MUTED\\])?"));
    const auto m = re.match(output.trimmed());
    if (!m.hasMatch())
        return std::nullopt;
    return std::pair{qRound(m.captured(1).toDouble() * 100), m.hasCaptured(2)};
}

bool SystemStatus::parseNmcliRadio(const QString &output)
{
    return output.trimmed() == QLatin1String("enabled");
}

bool SystemStatus::parseBluetoothPowered(const QString &output)
{
    static const QRegularExpression re(QStringLiteral("^\\s*Powered:\\s*yes\\s*$"), QRegularExpression::MultilineOption);
    return re.match(output).hasMatch();
}

std::pair<int, bool> SystemStatus::parseBattery(const QString &capacity, const QString &status)
{
    // Plugged in, not just "Charging": a full battery on the charger reports "Full" or "Not charging".
    return {capacity.trimmed().toInt(), status.trimmed() != QLatin1String("Discharging")};
}

bool SystemStatus::dndUntilActive(const QString &until, const QDateTime &now)
{
    const auto when = QDateTime::fromString(until.trimmed(), Qt::ISODate);
    return when.isValid() && when > now;
}

void SystemStatus::run(const QString &program, const QStringList &args, std::function<void(const QString &)> done)
{
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [proc, done] {
        if (done)
            done(QString::fromUtf8(proc->readAllStandardOutput()));
        proc->deleteLater();
    });
    proc->start(program, args);
}

void SystemStatus::refresh()
{
    readBattery();
    readDnd();
    readKeepAwake();
    run(QStringLiteral("wpctl"), {QStringLiteral("get-volume"), kSink}, [this](const QString &out) {
        if (const auto v = parseWpctlVolume(out)) {
            m_volume = v->first;
            m_muted = v->second;
            Q_EMIT changed();
        }
    });
    run(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi")}, [this](const QString &out) {
        m_wifi = parseNmcliRadio(out);
        Q_EMIT changed();
    });
    run(QStringLiteral("bluetoothctl"), {QStringLiteral("show")}, [this](const QString &out) {
        m_bluetooth = parseBluetoothPowered(out);
        Q_EMIT changed();
    });
}

void SystemStatus::readBattery()
{
    const auto [capacity, charging] = parseBattery(readFile(kBattery + QStringLiteral("capacity")), readFile(kBattery + QStringLiteral("status")));
    m_battery = capacity;
    m_charging = charging;
    Q_EMIT changed();
}

void SystemStatus::readDnd()
{
    // Plasma's own DND (tray) lives in plasmanotifyrc; other apps' holds show up as Inhibited.
    const QSettings rc(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/plasmanotifyrc"),
                       QSettings::IniFormat);
    const bool trayDnd = dndUntilActive(rc.value(QStringLiteral("DoNotDisturb/Until")).toString(), QDateTime::currentDateTime());
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.freedesktop.Notifications") << QStringLiteral("Inhibited");
    callAsync(this, get, [this, trayDnd](const QDBusMessage &reply) {
        const bool inhibited = !reply.arguments().isEmpty() && reply.arguments().first().value<QDBusVariant>().variant().toBool();
        m_dnd = m_dndCookie || trayDnd || inhibited;
        Q_EMIT changed();
    });
}

void SystemStatus::refreshEditMode()
{
    auto get = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.kde.PlasmaShell") << QStringLiteral("editMode");
    callAsync(this, get, [this](const QDBusMessage &reply) {
        const bool on = !reply.arguments().isEmpty() && reply.arguments().first().value<QDBusVariant>().variant().toBool();
        if (on != m_editMode) {
            m_editMode = on;
            Q_EMIT changed();
        }
    });
}

void SystemStatus::readKeepAwake()
{
    auto has = QDBusMessage::createMethodCall(QStringLiteral("org.kde.Solid.PowerManagement"), QStringLiteral("/org/kde/Solid/PowerManagement/PolicyAgent"),
                                              QStringLiteral("org.kde.Solid.PowerManagement.PolicyAgent"), QStringLiteral("HasInhibition"));
    has << kChangeScreenSettings;
    callAsync(this, has, [this](const QDBusMessage &reply) {
        const bool held = !reply.arguments().isEmpty() && reply.arguments().first().toBool();
        m_keepAwake = m_awakeCookie || held;
        Q_EMIT changed();
    });
}

void SystemStatus::toggleMute()
{
    run(QStringLiteral("wpctl"), {QStringLiteral("set-mute"), kSink, QStringLiteral("toggle")}, [this](const QString &) { refresh(); });
}

void SystemStatus::changeVolume(int deltaPercent)
{
    const auto step = QStringLiteral("%1%%2").arg(qAbs(deltaPercent)).arg(deltaPercent >= 0 ? QLatin1Char('+') : QLatin1Char('-'));
    run(QStringLiteral("wpctl"), {QStringLiteral("set-volume"), QStringLiteral("-l"), QStringLiteral("1.0"), kSink, step},
        [this](const QString &) { refresh(); });
}

void SystemStatus::setWifi(bool on)
{
    run(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi"), on ? QStringLiteral("on") : QStringLiteral("off")},
        [this](const QString &) { refresh(); });
}

void SystemStatus::setBluetooth(bool on)
{
    run(QStringLiteral("bluetoothctl"), {QStringLiteral("power"), on ? QStringLiteral("on") : QStringLiteral("off")},
        [this](const QString &) { refresh(); });
}

void SystemStatus::setDnd(bool on)
{
    if (on && !m_dndCookie) {
        m_dndCookie = callForCookie(notifyCall(QStringLiteral("Inhibit")) << QStringLiteral("dynamic-island") << QStringLiteral("Do not disturb")
                                                                       << QVariantMap());
    } else if (!on) {
        if (m_dndCookie) {
            QDBusConnection::sessionBus().send(notifyCall(QStringLiteral("UnInhibit")) << m_dndCookie);
            m_dndCookie = 0;
        }
        run(QStringLiteral("kwriteconfig6"),
            {QStringLiteral("--notify"), QStringLiteral("--file"), QStringLiteral("plasmanotifyrc"), QStringLiteral("--group"),
             QStringLiteral("DoNotDisturb"), QStringLiteral("--key"), QStringLiteral("Until"), QStringLiteral("--delete")},
            [this](const QString &) { readDnd(); });
    }
    readDnd();
}

void SystemStatus::setKeepAwake(bool on)
{
    if (on && !m_awakeCookie) {
        m_awakeCookie = callForCookie(screenSaverCall(QStringLiteral("Inhibit")) << QStringLiteral("dynamic-island") << QStringLiteral("Keep screen awake"));
    } else if (!on && m_awakeCookie) {
        QDBusConnection::sessionBus().send(screenSaverCall(QStringLiteral("UnInhibit")) << m_awakeCookie);
        m_awakeCookie = 0;
    }
    // The power daemon updates its inhibition list asynchronously.
    QTimer::singleShot(300, this, &SystemStatus::readKeepAwake);
}

void SystemStatus::screenshot()
{
    Q_EMIT aboutToScreenshot();
    QTimer::singleShot(300, this, [] { QProcess::startDetached(QStringLiteral("spectacle"), {}); });
}

void SystemStatus::pickColor()
{
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/ColorPicker"), QStringLiteral("org.kde.kwin.ColorPicker"),
                                              QStringLiteral("pick"));
    // Waits for the user's click, so no short timeout. A short delay lets the panel close first.
    QTimer::singleShot(300, this, [this, msg] {
        auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg, 5 * 60 * 1000), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
            watcher->deleteLater();
            const QDBusMessage reply = watcher->reply();
            if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
                return;
            // Sent as a struct holding one ARGB number.
            const QDBusArgument arg = reply.arguments().first().value<QDBusArgument>();
            uint argb = 0;
            arg.beginStructure();
            arg >> argb;
            arg.endStructure();
            Q_EMIT colorPicked(QColor::fromRgba(argb).name());
        });
    });
}

void SystemStatus::lock()
{
    QProcess::startDetached(QStringLiteral("loginctl"), {QStringLiteral("lock-session")});
}
