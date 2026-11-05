#pragma once

#include <QObject>
#include <QProcess>
#include <QVariantList>
#include <QTimer>
#include <qqmlintegration.h>

// How many repo packages have an update waiting, from `checkupdates` (pacman-contrib), run every 30 minutes while enabled.
// ponytail: repo packages only; AUR (`paru -Qua`) would be a second command and a second count.
class UpdatesWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    // -1 until the first check finishes, or when checkupdates is missing or failed.
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    // [{name, from, to}] for the updates found, in checkupdates' order.
    Q_PROPERTY(QVariantList packages READ packages NOTIFY countChanged)

public:
    explicit UpdatesWatcher(QObject *parent = nullptr);

    // checkupdates exits 0 with one line per update, 2 with none, anything else is an error.
    static int parse(int exitCode, const QByteArray &out);
    // "name old -> new" lines into {name, from, to}.
    static QVariantList parseList(const QByteArray &out);
    // The command that upgrades everything: an AUR helper if there is one, else pacman.
    static QStringList upgradeCommand(bool hasParu, bool hasYay);

    bool enabled() const { return m_timer.isActive(); }
    void setEnabled(bool on);
    int count() const { return m_count; }
    QVariantList packages() const { return m_packages; }
    // Opens a terminal (Konsole) running the upgrade; checks again once the database changes.
    Q_INVOKABLE void upgrade();

Q_SIGNALS:
    void enabledChanged();
    void countChanged();

private:
    void check();
    void setCount(int n);

    QTimer m_timer;
    QProcess m_proc;
    int m_count = -1;
    QVariantList m_packages;
};
