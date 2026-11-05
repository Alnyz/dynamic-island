#include "bluetoothwatcher.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMetaType>
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
    qDBusRegisterMetaType<BluezInterfaces>();
    qDBusRegisterMetaType<BluezObjects>();
    // An empty path matches every device.
    QDBusConnection::systemBus().connect(kBluez, QString(), kProps, QStringLiteral("PropertiesChanged"), this,
                                         SLOT(onPropertiesChanged(QString, QVariantMap, QStringList, QDBusMessage)));
    // Devices paired, removed, or their battery interface coming and going.
    const QString om = QStringLiteral("org.freedesktop.DBus.ObjectManager");
    QDBusConnection::systemBus().connect(kBluez, QStringLiteral("/"), om, QStringLiteral("InterfacesAdded"), this, SLOT(onObjectsChanged()));
    QDBusConnection::systemBus().connect(kBluez, QStringLiteral("/"), om, QStringLiteral("InterfacesRemoved"), this, SLOT(onObjectsChanged()));
    refresh();
}

void BluetoothWatcher::onObjectsChanged()
{
    refresh();
}

void BluetoothWatcher::refresh()
{
    auto msg = QDBusMessage::createMethodCall(kBluez, QStringLiteral("/"), QStringLiteral("org.freedesktop.DBus.ObjectManager"), QStringLiteral("GetManagedObjects"));
    auto *call = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg), this);
    connect(call, &QDBusPendingCallWatcher::finished, this, [this, call] {
        call->deleteLater();
        const QDBusPendingReply<BluezObjects> reply = *call;
        const QVariantList list = reply.isValid() ? connectedDevices(reply.value()) : QVariantList();
        if (list != m_devices) {
            m_devices = list;
            Q_EMIT devicesChanged();
        }
    });
}

QVariantList BluetoothWatcher::connectedDevices(const BluezObjects &objects)
{
    QList<QVariantMap> found;
    for (auto it = objects.cbegin(); it != objects.cend(); ++it) {
        const QVariantMap device = it.value().value(QStringLiteral("org.bluez.Device1"));
        if (device.isEmpty() || !device.value(QStringLiteral("Connected")).toBool())
            continue;
        QVariantMap d = describe(device, it.value().value(QStringLiteral("org.bluez.Battery1")), true);
        d.remove(QStringLiteral("connected"));
        d.insert(QStringLiteral("path"), it.key().path());
        found.append(d);
    }
    std::sort(found.begin(), found.end(), [](const QVariantMap &a, const QVariantMap &b) {
        return a.value(QStringLiteral("name")).toString().localeAwareCompare(b.value(QStringLiteral("name")).toString()) < 0;
    });
    QVariantList out;
    for (const QVariantMap &d : found)
        out.append(d);
    return out;
}

void BluetoothWatcher::onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &, const QDBusMessage &message)
{
    if (interface == QLatin1String("org.bluez.Battery1")) {
        refresh();
        return;
    }
    if (interface != QLatin1String("org.bluez.Device1") || !changed.contains(QStringLiteral("Connected")))
        return;
    // The list follows connections; the battery arrives a moment later and refreshes again.
    refresh();
    QTimer::singleShot(3000, this, &BluetoothWatcher::refresh);
    const bool connected = changed.value(QStringLiteral("Connected")).toBool();
    const QString path = message.path();
    // Battery1 shows up a moment after the connection, so give it time.
    QTimer::singleShot(connected ? 2500 : 0, this, [this, path, connected] { report(path, connected); });
}

void BluetoothWatcher::report(const QString &path, bool connected)
{
    // By value: the battery lookup runs after this call (and the timer that made it) is gone.
    auto getAll = [path](const QString &iface) {
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
