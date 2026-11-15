#include "updateswatcher.h"
#include <QFileSystemWatcher>
#include <QProcess>
#include <QStandardPaths>

UpdatesWatcher::UpdatesWatcher(QObject *parent)
: QObject(parent)
{
    m_timer.setInterval(30 * 60 * 1000);
    connect(&m_timer, &QTimer::timeout, this, &UpdatesWatcher::check);

    // Watch the dpkg database (installs, upgrades, removals) and apt's package lists (apt update).
    auto *watcher = new QFileSystemWatcher(this);
    watcher->addPath(QStringLiteral("/var/lib/dpkg"));
    watcher->addPath(QStringLiteral("/var/lib/apt/lists"));
    // Only while the count is wanted: otherwise every install would run apt for nothing.
    // An upgrade changes it once per package, so wait until it has been quiet for a few seconds.
    m_settle.setSingleShot(true);
    m_settle.setInterval(5000);
    connect(&m_settle, &QTimer::timeout, this, &UpdatesWatcher::check);
    connect(watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        if (enabled())
            m_settle.start();
    });

    connect(&m_proc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this, [this](int code, QProcess::ExitStatus status) {
        const QByteArray out = m_proc.readAllStandardOutput();
        m_packages = status == QProcess::NormalExit && code == 0 ? parseList(out) : QVariantList();
        const int n = status == QProcess::NormalExit ? parse(code, out) : -1;
        if (n == m_count)
            Q_EMIT countChanged(); // the list may have changed with the same count
        setCount(n);
        // The database changed while that run was going, so its answer may be out of date.
        if (m_again) {
            m_again = false;
            check();
        }
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
        m_settle.stop();
        m_again = false;
        m_packages.clear();
        setCount(-1);
    }
    Q_EMIT enabledChanged();
}

void UpdatesWatcher::check()
{
    if (m_proc.state() == QProcess::NotRunning)
        m_proc.start(QStringLiteral("apt"), {QStringLiteral("list"), QStringLiteral("--upgradable")});
    else
        m_again = true;
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
    if (exitCode != 0)
        return -1;
    return parseList(out).size();
}

QVariantList UpdatesWatcher::parseList(const QByteArray &out)
{
    QVariantList list;
    for (const QByteArray &raw : out.split('\n')) {
        // name/suite new-version arch [upgradable from: old-version]
        const QByteArray line = raw.simplified();
        const int slash = line.indexOf('/');
        const int from = line.indexOf("[upgradable from: ");
        if (slash <= 0 || from < 0)
            continue;
        const QList<QByteArray> parts = line.split(' ');
        if (parts.size() < 2)
            continue;
        QByteArray old = line.mid(from + 18);
        old.chop(1);
        list.append(QVariantMap{{QStringLiteral("name"), QString::fromUtf8(line.left(slash))},
                                {QStringLiteral("from"), QString::fromUtf8(old)},
                                {QStringLiteral("to"), QString::fromUtf8(parts.at(1))}});
    }
    return list;
}

QStringList UpdatesWatcher::upgradeCommand()
{
    return {QStringLiteral("sudo"), QStringLiteral("sh"), QStringLiteral("-c"), QStringLiteral("apt update && apt upgrade")};
}

void UpdatesWatcher::upgrade()
{
    const QStringList cmd = upgradeCommand();
    // --hold keeps the window open to read the result.
    QProcess::startDetached(QStringLiteral("konsole"), QStringList{QStringLiteral("--hold"), QStringLiteral("-e")} + cmd);
}
