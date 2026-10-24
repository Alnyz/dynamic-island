#include "camerawatcher.h"

#include <QFile>

#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>

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
    // Plain readdir/readlink: QDir and QFileInfo over every fd of every process cost ~0.2 s per pass.
    QStringList names;
    const QByteArray root = QFile::encodeName(procRoot);
    DIR *proc = opendir(root.constData());
    if (!proc)
        return names;
    while (const dirent *p = readdir(proc)) {
        if (p->d_name[0] < '0' || p->d_name[0] > '9')
            continue;
        const QByteArray pidDir = root + '/' + p->d_name;
        const QByteArray fdDir = pidDir + "/fd";
        // Other users' processes aren't readable; that's fine, the camera user is ours.
        DIR *fds = opendir(fdDir.constData());
        if (!fds)
            continue;
        bool camera = false;
        char target[64];
        while (const dirent *fd = readdir(fds)) {
            const ssize_t n = readlinkat(dirfd(fds), fd->d_name, target, sizeof target - 1);
            if (n >= 10 && qstrncmp(target, "/dev/video", 10) == 0) {
                camera = true;
                break;
            }
        }
        closedir(fds);
        if (!camera)
            continue;
        QFile comm(QFile::decodeName(pidDir + "/comm"));
        if (comm.open(QIODevice::ReadOnly)) {
            const QString name = QString::fromUtf8(comm.readAll()).trimmed();
            if (!names.contains(name))
                names.append(name);
        }
    }
    closedir(proc);
    names.sort();
    return names;
}
