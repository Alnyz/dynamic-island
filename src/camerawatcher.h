#pragma once

#include <QObject>
#include <QStringList>
#include <QTimer>
#include <qqmlintegration.h>

// Names of programs holding a camera (/dev/video*) open, checked every few seconds while enabled.
class CameraWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QStringList apps READ apps NOTIFY appsChanged)

public:
    explicit CameraWatcher(QObject *parent = nullptr);

    static QStringList scan(const QString &procRoot);

    bool enabled() const { return m_timer.isActive(); }
    void setEnabled(bool on);
    QStringList apps() const { return m_apps; }

Q_SIGNALS:
    void enabledChanged();
    void appsChanged();

private:
    void poll();

    QTimer m_timer;
    QStringList m_apps;
};
