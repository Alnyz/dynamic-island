#include "plasmasettings.h"

#include <KConfig>
#include <KConfigGroup>
#include <QStandardPaths>

PlasmaSettings::PlasmaSettings(QObject *parent)
    : PlasmaSettings(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation), parent)
{
}

PlasmaSettings::PlasmaSettings(const QString &configDir, QObject *parent)
    : QObject(parent)
    , m_dir(configDir)
{
}

// Plasma only notices changes announced for a config opened by its plain name.
QString PlasmaSettings::file(const QString &name) const
{
    return m_dir == QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) ? name : m_dir + QLatin1Char('/') + name;
}

void PlasmaSettings::setOsdEnabled(bool on)
{
    KConfig rc(file(QStringLiteral("plasmarc")), KConfig::NoGlobals);
    KConfigGroup group(&rc, QStringLiteral("OSD"));
    if (on)
        group.deleteEntry("Enabled", KConfig::Notify);
    else
        group.writeEntry("Enabled", false, KConfig::Notify);
    rc.sync();
}

bool PlasmaSettings::osdEnabled() const
{
    KConfig rc(file(QStringLiteral("plasmarc")), KConfig::NoGlobals);
    return KConfigGroup(&rc, QStringLiteral("OSD")).readEntry("Enabled", true);
}

void PlasmaSettings::setPopupsEnabled(bool on)
{
    KConfig rc(file(QStringLiteral("plasmanotifyrc")), KConfig::NoGlobals);
    KConfigGroup apps(&rc, QStringLiteral("Applications"));
    for (const QString &name : apps.groupList()) {
        KConfigGroup app(&apps, name);
        if (on)
            app.deleteEntry("ShowPopups", KConfig::Notify);
        else
            app.writeEntry("ShowPopups", false, KConfig::Notify);
    }
    rc.sync();
}

void PlasmaSettings::hidePopupsFor(const QString &desktopEntry)
{
    if (desktopEntry.isEmpty() || !popupsEnabled(desktopEntry))
        return;
    KConfig rc(file(QStringLiteral("plasmanotifyrc")), KConfig::NoGlobals);
    KConfigGroup(&rc, QStringLiteral("Applications")).group(desktopEntry).writeEntry("ShowPopups", false, KConfig::Notify);
    rc.sync();
}

bool PlasmaSettings::popupsEnabled(const QString &desktopEntry) const
{
    KConfig rc(file(QStringLiteral("plasmanotifyrc")), KConfig::NoGlobals);
    return KConfigGroup(&rc, QStringLiteral("Applications")).group(desktopEntry).readEntry("ShowPopups", true);
}
