#include "blursettings.h"

#include <KConfig>
#include <KConfigGroup>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>

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
    QString found;
    for (const QString &id : {QStringLiteral("better_blur_dx"), QStringLiteral("forceblur"), QStringLiteral("blur")}) {
        const QDBusReply<bool> loaded = QDBusConnection::sessionBus().call(effects(QStringLiteral("isEffectLoaded")) << id);
        if (loaded.isValid() && loaded.value()) {
            found = id;
            break;
        }
    }
    if (found != m_effect) {
        m_effect = found;
        Q_EMIT changed();
    }
}

int BlurSettings::strength() const
{
    if (m_effect.isEmpty())
        return kDefaultStrength;
    KConfig config(m_config, KConfig::SimpleConfig);
    return qBound(1, config.group(groupFor(m_effect)).readEntry("BlurStrength", kDefaultStrength), 15);
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
    // KWin rereads the effect's settings straight away.
    if (m_live)
        QDBusConnection::sessionBus().call(effects(QStringLiteral("reconfigureEffect")) << m_effect);
    Q_EMIT changed();
}
