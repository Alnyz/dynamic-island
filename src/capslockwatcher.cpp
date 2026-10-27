#include "capslockwatcher.h"

#include <QDir>
#include <QFile>

CapsLockWatcher::CapsLockWatcher(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(250);
    connect(&m_timer, &QTimer::timeout, this, &CapsLockWatcher::poll);
}

void CapsLockWatcher::setEnabled(bool on)
{
    if (on == enabled())
        return;
    if (on) {
        m_timer.start();
        poll();
    } else {
        m_timer.stop();
        if (m_on) {
            m_on = false;
            Q_EMIT onChanged();
        }
    }
    Q_EMIT enabledChanged();
}

void CapsLockWatcher::poll()
{
    const bool now = read(QStringLiteral("/sys/class/leds"));
    if (now != m_on) {
        m_on = now;
        Q_EMIT onChanged();
    }
}

bool CapsLockWatcher::read(const QString &ledRoot)
{
    const QDir root(ledRoot);
    for (const QString &led : root.entryList({QStringLiteral("*capslock")}, QDir::Dirs | QDir::NoDotAndDotDot)) {
        QFile f(root.filePath(led + QStringLiteral("/brightness")));
        if (f.open(QIODevice::ReadOnly) && f.readAll().trimmed().toInt() > 0)
            return true;
    }
    return false;
}
