#include "updateswatcher.h"

UpdatesWatcher::UpdatesWatcher(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(30 * 60 * 1000);
    connect(&m_timer, &QTimer::timeout, this, &UpdatesWatcher::check);
    connect(&m_proc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        setCount(status == QProcess::NormalExit ? parse(code, m_proc.readAllStandardOutput()) : -1);
    });
    connect(&m_proc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart)
            setCount(-1);
    });
}

void UpdatesWatcher::setEnabled(bool on)
{
    if (on == enabled())
        return;
    if (on) {
        m_timer.start();
        check();
    } else {
        m_timer.stop();
        setCount(-1);
    }
    Q_EMIT enabledChanged();
}

void UpdatesWatcher::check()
{
    if (m_proc.state() == QProcess::NotRunning)
        m_proc.start(QStringLiteral("checkupdates"), {});
}

void UpdatesWatcher::setCount(int n)
{
    if (n != m_count) {
        m_count = n;
        Q_EMIT countChanged();
    }
}

int UpdatesWatcher::parse(int exitCode, const QByteArray &out)
{
    if (exitCode == 2)
        return 0;
    if (exitCode != 0)
        return -1;
    return out.trimmed().isEmpty() ? 0 : out.trimmed().split('\n').size();
}
