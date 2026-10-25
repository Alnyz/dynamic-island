#pragma once

#include <QObject>
#include <QVariantMap>
#include <qqmlintegration.h>

class QSocketNotifier;
struct DBusConnection;
struct DBusMessage;

// Listens to the progress apps report to Plasma's job tracker; a monitor connection, so it never answers.
class JobWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit JobWatcher(QObject *parent = nullptr);
    ~JobWatcher() override;

    bool enabled() const { return m_conn != nullptr; }
    void setEnabled(bool on);

    // The a{sv} of an update call; strings, integers (as qlonglong) and bools only.
    static QVariantMap readProps(DBusMessage *update);
    // Sender and object path: one job.
    static QString key(DBusMessage *message);

Q_SIGNALS:
    void enabledChanged();
    void updated(const QString &key, const QVariantMap &props);
    void ended(const QString &key, int code, const QString &error);
    // An app left the bus, taking any jobs it never ended with it.
    void ownerGone(const QString &sender);

private:
    friend class TestWatchers;
    void handle(DBusMessage *message);
    void dispatch();
    void close();

    DBusConnection *m_conn = nullptr;
    QSocketNotifier *m_notifier = nullptr;
};
