#pragma once

#include <QObject>
#include <qqmlintegration.h>

// Owns ~/.config/dynamic-island.conf, which may hold secret calendar links, so it is kept private (0600).
class AppConfig : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString path READ path CONSTANT)
    Q_PROPERTY(bool autostart READ autostart WRITE setAutostart NOTIFY autostartChanged)

public:
    explicit AppConfig(QObject *parent = nullptr);
    explicit AppConfig(const QString &path, QObject *parent = nullptr);

    QString path() const { return m_path; }
    bool autostart() const;
    void setAutostart(bool on);

    static QString defaultPath();
    static QString autostartPath();

Q_SIGNALS:
    void autostartChanged();

private:
    QString m_path;
};
