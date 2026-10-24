#include "appconfig.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

QString AppConfig::defaultPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/dynamic-island.conf");
}

QString AppConfig::autostartPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/autostart/dynamic-island.desktop");
}

AppConfig::AppConfig(QObject *parent)
    : AppConfig(defaultPath(), parent)
{
}

AppConfig::AppConfig(const QString &path, QObject *parent)
    : QObject(parent)
    , m_path(path)
{
    // Create it before the settings page can write to it, so it is never readable by others.
    QFile file(path);
    if (!file.exists() && file.open(QIODevice::WriteOnly))
        file.close();
    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

bool AppConfig::autostart() const
{
    return QFile::exists(autostartPath());
}

void AppConfig::setAutostart(bool on)
{
    if (on == autostart())
        return;
    const QString entry = autostartPath();
    if (on) {
        QDir().mkpath(QFileInfo(entry).path());
        QFile file(entry);
        if (!file.open(QIODevice::WriteOnly))
            return;
        file.write("[Desktop Entry]\nType=Application\nName=Dynamic Island\nComment=Song and controls at the top of the screen\nExec=");
        file.write(QCoreApplication::applicationFilePath().toUtf8());
        file.write("\nIcon=media-playback-start\nTerminal=false\nX-KDE-autostart-after=panel\n");
    } else {
        QFile::remove(entry);
    }
    Q_EMIT autostartChanged();
}
