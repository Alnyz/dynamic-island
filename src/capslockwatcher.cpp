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
        if (m_num) {
            m_num = false;
            Q_EMIT numLockChanged();
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
    const bool num = read(QStringLiteral("/sys/class/leds"), QStringLiteral("numlock"));
    if (num != m_num) {
        m_num = num;
        Q_EMIT numLockChanged();
    }
}

bool CapsLockWatcher::read(const QString &ledRoot)
{
    return read(ledRoot, QStringLiteral("capslock"));
}

bool CapsLockWatcher::read(const QString &ledRoot, const QString &suffix)
{
    const QDir root(ledRoot);
    for (const QString &led : root.entryList({QStringLiteral("*") + suffix}, QDir::Dirs | QDir::NoDotAndDotDot)) {
        QFile f(root.filePath(led + QStringLiteral("/brightness")));
        if (f.open(QIODevice::ReadOnly) && f.readAll().trimmed().toInt() > 0)
            return true;
    }
    return false;
}
