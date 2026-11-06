#include "capslockwatcher.h"

#include <QDir>
#include <QFile>

CapsLockWatcher::CapsLockWatcher(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(250);
    connect(&m_timer, &QTimer::timeout, this, [this] { poll(); });
}

void CapsLockWatcher::setEnabled(bool on)
{
    if (on == enabled())
        return;
    if (on) {
        m_timer.start();
        // What's already on isn't news: only keys pressed from now on get an alert.
        poll(false);
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

void CapsLockWatcher::poll(bool announce)
{
    const bool now = read(m_ledRoot);
    if (now != m_on) {
        m_on = now;
        Q_EMIT onChanged();
        if (announce)
            Q_EMIT capsLockPressed();
    }
    const bool num = read(m_ledRoot, QStringLiteral("numlock"));
    if (num != m_num) {
        m_num = num;
        Q_EMIT numLockChanged();
        if (announce)
            Q_EMIT numLockPressed();
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
