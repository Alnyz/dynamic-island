#pragma once

#include <QDateTime>
#include <QObject>
#include <QStringList>
#include <functional>
#include <optional>
#include <qqmlintegration.h>
#include <utility>

class SystemStatus : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int battery MEMBER m_battery NOTIFY changed)
    Q_PROPERTY(bool charging MEMBER m_charging NOTIFY changed)
    Q_PROPERTY(int volume MEMBER m_volume NOTIFY changed)
    Q_PROPERTY(bool muted MEMBER m_muted NOTIFY changed)
    Q_PROPERTY(bool wifi MEMBER m_wifi NOTIFY changed)
    Q_PROPERTY(bool bluetooth MEMBER m_bluetooth NOTIFY changed)
    Q_PROPERTY(bool dnd MEMBER m_dnd NOTIFY changed)
    Q_PROPERTY(bool keepAwake MEMBER m_keepAwake NOTIFY changed)
    Q_PROPERTY(bool editMode MEMBER m_editMode NOTIFY changed)
    // No keyboard or pointer input for a minute; the idle animation pauses.
    Q_PROPERTY(bool userIdle MEMBER m_userIdle NOTIFY changed)

public:
    explicit SystemStatus(QObject *parent = nullptr);
    ~SystemStatus() override;

    static std::optional<std::pair<int, bool>> parseWpctlVolume(const QString &output);
    static bool parseNmcliRadio(const QString &output);
    static bool parseBluetoothPowered(const QString &output);
    static std::pair<int, bool> parseBattery(const QString &capacity, const QString &status);
    static bool dndUntilActive(const QString &until, const QDateTime &now);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshBattery() { readBattery(); }
    // Plasma announces no change to its edit mode, so it has to be asked.
    Q_INVOKABLE void refreshEditMode();
    // Reads do-not-disturb now; notifications arrive between panel opens.
    Q_INVOKABLE bool dndActive() { readDnd(); return m_dnd; }
    Q_INVOKABLE void toggleMute();
    Q_INVOKABLE void changeVolume(int deltaPercent);
    Q_INVOKABLE void setWifi(bool on);
    Q_INVOKABLE void setBluetooth(bool on);
    Q_INVOKABLE void setDnd(bool on);
    Q_INVOKABLE void setKeepAwake(bool on);
    Q_INVOKABLE void screenshot();
    Q_INVOKABLE void lock();
    // KWin's picker: the next click anywhere on screen; Escape cancels and nothing is sent.
    Q_INVOKABLE void pickColor();

Q_SIGNALS:
    void changed();
    void aboutToScreenshot();
    void brightnessChanged(int percent);
    void colorPicked(const QString &hex);

private Q_SLOTS:
    void onBrightnessChanged(const QString &display, int value, const QString &sourceClient, const QString &sourceContext);

private:
    void run(const QString &program, const QStringList &args, std::function<void(const QString &)> done = {});
    void readBattery();
    void readDnd();
    void readKeepAwake();

    int m_battery = -1;
    bool m_charging = false;
    int m_volume = 0;
    bool m_muted = false;
    bool m_wifi = false;
    bool m_bluetooth = false;
    bool m_dnd = false;
    bool m_keepAwake = false;
    bool m_editMode = false;
    bool m_userIdle = false;
    uint m_dndCookie = 0;
    uint m_awakeCookie = 0;
};
