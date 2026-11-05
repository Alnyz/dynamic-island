#pragma once

#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QMap>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlintegration.h>

// BlueZ's GetManagedObjects reply: object path -> interface -> properties.
using BluezInterfaces = QMap<QString, QVariantMap>;
using BluezObjects = QMap<QDBusObjectPath, BluezInterfaces>;

// Reports BlueZ devices connecting and disconnecting, with their battery when they share it,
// and keeps the list of connected devices for the panel and the idle pill.
class BluetoothWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // Connected devices: [{path, name, icon, battery (-1 when unknown)}], by name.
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)

public:
    explicit BluetoothWatcher(QObject *parent = nullptr);

    // {name, icon, connected, battery (-1 when unknown)} from org.bluez.Device1 and Battery1 properties.
    static QVariantMap describe(const QVariantMap &device, const QVariantMap &battery, bool connected);
    // The connected devices among BlueZ's objects.
    static QVariantList connectedDevices(const BluezObjects &objects);

    QVariantList devices() const { return m_devices; }
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void deviceChanged(const QVariantMap &device);
    void devicesChanged();

private Q_SLOTS:
    void onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated, const QDBusMessage &message);

    void onObjectsChanged();

private:
    void report(const QString &path, bool connected);
    QVariantList m_devices;
};
