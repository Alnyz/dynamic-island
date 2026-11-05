#include "updateswatcher.h"
#include <QFileSystemWatcher>
#include <QProcess>
#include <QStandardPaths>

UpdatesWatcher::UpdatesWatcher(QObject *parent)
: QObject(parent)
{
    m_timer.setInterval(30 * 60 * 1000);
    connect(&m_timer, &QTimer::timeout, this, &UpdatesWatcher::check);

    // Watch local pacman database for package changes (installs, upgrades, removals)
    auto *watcher = new QFileSystemWatcher(this);
    watcher->addPath(QStringLiteral("/var/lib/pacman/local"));
    // Only while the count is wanted: otherwise every install would run checkupdates for nothing.
    connect(watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        if (enabled())
            check();
    });

    connect(&m_proc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        const QByteArray out = m_proc.readAllStandardOutput();
        m_packages = status == QProcess::NormalExit && code == 0 ? parseList(out) : QVariantList();
        const int n = status == QProcess::NormalExit ? parse(code, out) : -1;
        if (n == m_count)
            Q_EMIT countChanged(); // the list may have changed with the same count
        setCount(n);
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
        m_packages.clear();
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

QVariantList UpdatesWatcher::parseList(const QByteArray &out)
{
    QVariantList list;
    for (const QByteArray &raw : out.split('\n')) {
        const QList<QByteArray> parts = raw.simplified().split(' ');
        // name old -> new
        if (parts.size() < 4 || parts.at(2) != "->")
            continue;
        list.append(QVariantMap{{QStringLiteral("name"), QString::fromUtf8(parts.at(0))},
                                {QStringLiteral("from"), QString::fromUtf8(parts.at(1))},
                                {QStringLiteral("to"), QString::fromUtf8(parts.at(3))}});
    }
    return list;
}

QStringList UpdatesWatcher::upgradeCommand(bool hasParu, bool hasYay)
{
    if (hasParu)
        return {QStringLiteral("paru"), QStringLiteral("-Syu")};
    if (hasYay)
        return {QStringLiteral("yay"), QStringLiteral("-Syu")};
    return {QStringLiteral("sudo"), QStringLiteral("pacman"), QStringLiteral("-Syu")};
}

void UpdatesWatcher::upgrade()
{
    const QStringList cmd = upgradeCommand(!QStandardPaths::findExecutable(QStringLiteral("paru")).isEmpty(),
                                           !QStandardPaths::findExecutable(QStringLiteral("yay")).isEmpty());
    // --hold keeps the window open to read the result.
    QProcess::startDetached(QStringLiteral("konsole"), QStringList{QStringLiteral("--hold"), QStringLiteral("-e")} + cmd);
}
