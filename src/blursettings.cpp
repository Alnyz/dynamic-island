#include "blursettings.h"

#include <KConfig>
#include <KConfigGroup>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>

namespace
{
QDBusMessage effects(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"), QStringLiteral("org.kde.kwin.Effects"), method);
}
}

BlurSettings::BlurSettings(QObject *parent)
    : QObject(parent)
    , m_config(QStringLiteral("kwinrc"))
{
    refresh();
}

BlurSettings::BlurSettings(const QString &configFile, const QString &effect, QObject *parent)
    : QObject(parent)
    , m_config(configFile)
    , m_effect(effect)
    , m_live(false)
{
    readStrength();
}

QString BlurSettings::groupFor(const QString &effect)
{
    if (effect == QLatin1String("better_blur_dx"))
        return QStringLiteral("Effect-better-blur-dx");
    return QStringLiteral("Effect-") + effect;
}

void BlurSettings::refresh()
{
    if (!m_live)
        return;
    // Asked without waiting, so a slow KWin at login doesn't hold up the island.
    QDBusMessage get = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
                                                      QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    get << QStringLiteral("org.kde.kwin.Effects") << QStringLiteral("loadedEffects");
    auto *watch = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(get), this);
    connect(watch, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        const QDBusPendingReply<QDBusVariant> reply = *w;
        const QStringList loaded = reply.isValid() ? reply.value().variant().toStringList() : QStringList();
        QString found;
        for (const QString &id : {QStringLiteral("better_blur_dx"), QStringLiteral("forceblur"), QStringLiteral("blur")}) {
            if (loaded.contains(id)) {
                found = id;
                break;
            }
        }
        m_effect = found;
        readStrength();
        Q_EMIT changed();
    });
}

void BlurSettings::readStrength()
{
    if (m_effect.isEmpty()) {
        m_strength = kDefaultStrength;
        return;
    }
    KConfig config(m_config, KConfig::SimpleConfig);
    m_strength = qBound(1, config.group(groupFor(m_effect)).readEntry("BlurStrength", kDefaultStrength), 15);
}

void BlurSettings::setStrength(int value)
{
    if (m_effect.isEmpty())
        return;
    value = qBound(1, value, 15);
    if (value == strength())
        return;
    KConfig config(m_config, KConfig::SimpleConfig);
    KConfigGroup group = config.group(groupFor(m_effect));
    group.writeEntry("BlurStrength", value);
    config.sync();
    m_strength = value;
    // KWin rereads the effect's settings straight away.
    if (m_live)
        QDBusConnection::sessionBus().asyncCall(effects(QStringLiteral("reconfigureEffect")) << m_effect);
    Q_EMIT changed();
}
