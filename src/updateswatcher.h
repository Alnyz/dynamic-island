#pragma once

#include <QObject>
#include <QProcess>
#include <QVariantList>
#include <QTimer>
#include <QtQml/qqml.h>

// How many packages have an update waiting, from `apt list --upgradable`, run every 30 minutes while enabled.
class UpdatesWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    // -1 until the first check finishes, or when apt failed.
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    // [{name, from, to}] for the updates found, in apt's order.
    Q_PROPERTY(QVariantList packages READ packages NOTIFY countChanged)

public:
    explicit UpdatesWatcher(QObject *parent = nullptr);

    // The number of upgradable packages in apt's output, or -1 when apt failed.
    static int parse(int exitCode, const QByteArray &out);
    // "name/suite new arch [upgradable from: old]" lines into {name, from, to}.
    static QVariantList parseList(const QByteArray &out);
    // The command that upgrades everything.
    static QStringList upgradeCommand();

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
    QTimer m_settle;
    bool m_again = false;
    QProcess m_proc;
    int m_count = -1;
    QVariantList m_packages;
};
