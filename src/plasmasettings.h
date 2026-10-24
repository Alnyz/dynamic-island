#pragma once

#include <QObject>
#include <qqmlintegration.h>

// Switches off Plasma's own volume/brightness box and notification popups while the island shows them.
class PlasmaSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit PlasmaSettings(QObject *parent = nullptr);
    explicit PlasmaSettings(const QString &configDir, QObject *parent = nullptr);

    Q_INVOKABLE void setOsdEnabled(bool on);
    bool osdEnabled() const;

    // Plasma only has a per-app popup switch, so it is set for every app it has seen.
    Q_INVOKABLE void setPopupsEnabled(bool on);
    // For an app notifying for the first time; its first popup may still show.
    Q_INVOKABLE void hidePopupsFor(const QString &desktopEntry);
    bool popupsEnabled(const QString &desktopEntry) const;

private:
    QString file(const QString &name) const;

    QString m_dir;
};
