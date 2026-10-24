#include "camerawatcher.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>

CameraWatcher::CameraWatcher(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(3000);
    connect(&m_timer, &QTimer::timeout, this, &CameraWatcher::poll);
}

void CameraWatcher::setEnabled(bool on)
{
    if (on == enabled())
        return;
    if (on) {
        m_timer.start();
        poll();
    } else {
        m_timer.stop();
        if (!m_apps.isEmpty()) {
            m_apps.clear();
            Q_EMIT appsChanged();
        }
    }
    Q_EMIT enabledChanged();
}

void CameraWatcher::poll()
{
    const QStringList found = scan(QStringLiteral("/proc"));
    if (found != m_apps) {
        m_apps = found;
        Q_EMIT appsChanged();
    }
}

QStringList CameraWatcher::scan(const QString &procRoot)
{
    QStringList names;
    const QStringList pids = QDir(procRoot).entryList({QStringLiteral("[0-9]*")}, QDir::Dirs);
    for (const QString &pid : pids) {
        const QString fdDir = procRoot + QLatin1Char('/') + pid + QStringLiteral("/fd");
        // Other users' processes aren't readable; that's fine, the camera user is ours.
        const QFileInfoList fds = QDir(fdDir).entryInfoList(QDir::System | QDir::NoDotAndDotDot);
        for (const QFileInfo &fd : fds) {
            if (fd.symLinkTarget().startsWith(QLatin1String("/dev/video"))) {
                QFile comm(procRoot + QLatin1Char('/') + pid + QStringLiteral("/comm"));
                if (comm.open(QIODevice::ReadOnly)) {
                    const QString name = QString::fromUtf8(comm.readAll()).trimmed();
                    if (!names.contains(name))
                        names.append(name);
                }
                break;
            }
        }
    }
    names.sort();
    return names;
}
