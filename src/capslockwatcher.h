#pragma once

#include <QObject>
#include <QTimer>
#include <qqmlintegration.h>

// Whether Caps Lock and Num Lock are on, read from the keyboard LEDs under /sys/class/leds while enabled.
// ponytail: polled every 250 ms because sysfs has no change events; swap in a libinput/evdev watch if that ever shows in a profile.
class CapsLockWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool on READ on NOTIFY onChanged)
    Q_PROPERTY(bool numLock READ numLock NOTIFY numLockChanged)

public:
    explicit CapsLockWatcher(QObject *parent = nullptr);

    // True when any *capslock LED under ledRoot is lit.
    static bool read(const QString &ledRoot);
    // The same for any LED whose name ends in suffix ("numlock").
    static bool read(const QString &ledRoot, const QString &suffix);

    bool enabled() const { return m_timer.isActive(); }
    void setEnabled(bool on);
    bool on() const { return m_on; }
    bool numLock() const { return m_num; }
    // For tests; the real LEDs otherwise.
    void setLedRoot(const QString &root) { m_ledRoot = root; }
    // The same as one timer tick.
    void pollNow() { poll(); }

Q_SIGNALS:
    void enabledChanged();
    void onChanged();
    void numLockChanged();
    // A key was pressed, unlike the changes above, which also follow enabled being switched.
    void capsLockPressed();
    void numLockPressed();

private:
    void poll(bool announce = true);

    QString m_ledRoot = QStringLiteral("/sys/class/leds");
    QTimer m_timer;
    bool m_on = false;
    bool m_num = false;
};
