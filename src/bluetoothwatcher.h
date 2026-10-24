#pragma once

#include <QDBusMessage>
#include <QObject>
#include <QVariantMap>
#include <qqmlintegration.h>

// Reports BlueZ devices connecting and disconnecting, with their battery when they share it.
class BluetoothWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit BluetoothWatcher(QObject *parent = nullptr);

    // {name, icon, connected, battery (-1 when unknown)} from org.bluez.Device1 and Battery1 properties.
    static QVariantMap describe(const QVariantMap &device, const QVariantMap &battery, bool connected);

Q_SIGNALS:
    void deviceChanged(const QVariantMap &device);

private Q_SLOTS:
    void onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated, const QDBusMessage &message);

private:
    void report(const QString &path, bool connected);
};
