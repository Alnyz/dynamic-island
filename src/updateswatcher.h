#pragma once

#include <QObject>
#include <QProcess>
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

public:
    explicit UpdatesWatcher(QObject *parent = nullptr);

    // checkupdates exits 0 with one line per update, 2 with none, anything else is an error.
    static int parse(int exitCode, const QByteArray &out);

    bool enabled() const { return m_timer.isActive(); }
    void setEnabled(bool on);
    int count() const { return m_count; }

Q_SIGNALS:
    void enabledChanged();
    void countChanged();

private:
    void check();
    void setCount(int n);

    QTimer m_timer;
    QProcess m_proc;
    int m_count = -1;
};
