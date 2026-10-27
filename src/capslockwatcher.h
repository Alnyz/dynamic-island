#pragma once

#include <QObject>
#include <QTimer>
#include <qqmlintegration.h>

// Whether Caps Lock is on, read from the keyboard LEDs under /sys/class/leds while enabled.
// ponytail: polled every 250 ms because sysfs has no change events; swap in a libinput/evdev watch if that ever shows in a profile.
class CapsLockWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool on READ on NOTIFY onChanged)

public:
    explicit CapsLockWatcher(QObject *parent = nullptr);

    // True when any *capslock LED under ledRoot is lit.
    static bool read(const QString &ledRoot);

    bool enabled() const { return m_timer.isActive(); }
    void setEnabled(bool on);
    bool on() const { return m_on; }

Q_SIGNALS:
    void enabledChanged();
    void onChanged();

private:
    void poll();

    QTimer m_timer;
    bool m_on = false;
};
