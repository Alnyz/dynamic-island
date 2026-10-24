#include "bluetoothwatcher.h"

#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QTimer>

namespace
{
const QString kBluez = QStringLiteral("org.bluez");
const QString kProps = QStringLiteral("org.freedesktop.DBus.Properties");
}

BluetoothWatcher::BluetoothWatcher(QObject *parent)
    : QObject(parent)
{
    // An empty path matches every device.
    QDBusConnection::systemBus().connect(kBluez, QString(), kProps, QStringLiteral("PropertiesChanged"), this,
                                         SLOT(onPropertiesChanged(QString, QVariantMap, QStringList, QDBusMessage)));
}

void BluetoothWatcher::onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &, const QDBusMessage &message)
{
    if (interface != QLatin1String("org.bluez.Device1") || !changed.contains(QStringLiteral("Connected")))
        return;
    const bool connected = changed.value(QStringLiteral("Connected")).toBool();
    const QString path = message.path();
    // Battery1 shows up a moment after the connection, so give it time.
    QTimer::singleShot(connected ? 2500 : 0, this, [this, path, connected] { report(path, connected); });
}

void BluetoothWatcher::report(const QString &path, bool connected)
{
    auto getAll = [&](const QString &iface) {
        auto msg = QDBusMessage::createMethodCall(kBluez, path, kProps, QStringLiteral("GetAll"));
        msg << iface;
        return QDBusConnection::systemBus().asyncCall(msg);
    };
    auto *device = new QDBusPendingCallWatcher(getAll(QStringLiteral("org.bluez.Device1")), this);
    connect(device, &QDBusPendingCallWatcher::finished, this, [=, this] {
        device->deleteLater();
        const QVariantMap props = QDBusPendingReply<QVariantMap>(*device).value();
        auto *battery = new QDBusPendingCallWatcher(getAll(QStringLiteral("org.bluez.Battery1")), this);
        connect(battery, &QDBusPendingCallWatcher::finished, this, [=, this] {
            battery->deleteLater();
            Q_EMIT deviceChanged(describe(props, QDBusPendingReply<QVariantMap>(*battery).value(), connected));
        });
    });
}

QVariantMap BluetoothWatcher::describe(const QVariantMap &device, const QVariantMap &battery, bool connected)
{
    const QString alias = device.value(QStringLiteral("Alias")).toString();
    return {
        {QStringLiteral("name"), alias.isEmpty() ? device.value(QStringLiteral("Name")).toString() : alias},
        {QStringLiteral("icon"), device.value(QStringLiteral("Icon"), QStringLiteral("bluetooth")).toString()},
        {QStringLiteral("connected"), connected},
        {QStringLiteral("battery"), battery.contains(QStringLiteral("Percentage")) ? battery.value(QStringLiteral("Percentage")).toInt() : -1},
    };
}
