#pragma once

#include <QDBusContext>
#include <QHash>
#include <functional>
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

    // Asks the player named identity, on the song named title, for its position; the answer comes as
    // positionRead. Plasma can't do this: asking it to read the position again leaves its copy as it was.
    Q_INVOKABLE void askPosition(const QString &identity, const QString &title);

Q_SIGNALS:
    // identity and title: the player's MPRIS Identity and song, as Plasma shows them; position in
    // microseconds.
    void seeked(const QString &identity, const QString &title, qlonglong position);
    void positionRead(const QString &identity, const QString &title, qlonglong position);

private Q_SLOTS:
    void onSeeked(qlonglong position);

private:
    void readPosition(const QString &identity, const QString &title, const QString &service);
    void title(const QString &service, std::function<void(const QString &)> done);
    void get(const QString &service, const QString &iface, const QString &name, std::function<void(const QVariant &)> done);

    // Identity and title -> bus address, so the bus is searched once per song.
    // ponytail: two players with one name on the same title can't be told apart; Plasma's QML
    // doesn't give the bus address.
    QHash<QString, QString> m_services;
};
