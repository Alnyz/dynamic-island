#pragma once

#include <QDBusContext>
#include <QObject>
#include <qqmlintegration.h>

// Every MPRIS player's Seeked signal, passed on as is. Plasma's copy of a player's position only
// changes when the new value differs from the one it holds, and a player that never announces its
// position as it moves leaves that copy at the song's start: a song starting over (repeat one,
// previous) seeks to 0 and Plasma passes nothing on.
class MprisSeeks : public QObject, protected QDBusContext
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit MprisSeeks(QObject *parent = nullptr);

Q_SIGNALS:
    // identity: the player's MPRIS Identity, as Plasma shows it; position in microseconds.
    void seeked(const QString &identity, qlonglong position);

private Q_SLOTS:
    void onSeeked(qlonglong position);
};
