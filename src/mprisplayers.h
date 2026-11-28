#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqml.h>

class QDBusPendingCallWatcher;
class QTimer;

// One MPRIS player, with the same property names and numbering as the player containers of
// Plasma 6's private MPRIS module, which Plasma 5 doesn't have.
class MprisPlayer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString identity READ identity NOTIFY identityChanged)
    Q_PROPERTY(QString desktopEntry READ desktopEntry NOTIFY desktopEntryChanged)
    Q_PROPERTY(QString iconName READ iconName NOTIFY desktopEntryChanged)
    Q_PROPERTY(QString track READ track NOTIFY trackChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY artistChanged)
    Q_PROPERTY(QString album READ album NOTIFY albumChanged)
    Q_PROPERTY(QString artUrl READ artUrl NOTIFY artUrlChanged)
    // Microseconds, as MPRIS gives them.
    Q_PROPERTY(double length READ length NOTIFY lengthChanged)
    Q_PROPERTY(double position READ position WRITE setPosition NOTIFY positionChanged)
    // Playback speed, 1 at normal speed; MPRIS Rate.
    Q_PROPERTY(double rate READ rate NOTIFY rateChanged)
    Q_PROPERTY(int playbackStatus READ playbackStatus NOTIFY playbackStatusChanged)
    Q_PROPERTY(int loopStatus READ loopStatus WRITE setLoopStatus NOTIFY loopStatusChanged)
    Q_PROPERTY(int shuffle READ shuffle WRITE setShuffle NOTIFY shuffleChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool canSeek READ canSeek NOTIFY capsChanged)
    Q_PROPERTY(bool canGoNext READ canGoNext NOTIFY capsChanged)
    Q_PROPERTY(bool canGoPrevious READ canGoPrevious NOTIFY capsChanged)
    Q_PROPERTY(bool canPlay READ canPlay NOTIFY capsChanged)
    Q_PROPERTY(bool canPause READ canPause NOTIFY capsChanged)
    Q_PROPERTY(bool canControl READ canControl NOTIFY capsChanged)
    Q_PROPERTY(bool canRaise READ canRaise NOTIFY capsChanged)

public:
    enum Status { Unknown = 0, Stopped = 1, Playing = 2, Paused = 3 };

    MprisPlayer(const QString &service, QObject *parent = nullptr);

    QString service() const { return m_service; }
    QString identity() const { return m_identity; }
    QString desktopEntry() const { return m_desktopEntry; }
    QString iconName() const { return m_iconName; }
    QString track() const { return m_track; }
    QString artist() const { return m_artist; }
    QString album() const { return m_album; }
    QString artUrl() const { return m_artUrl; }
    double length() const { return m_length; }
    double position() const;
    void setPosition(double us);
    double rate() const { return m_rate; }
    int playbackStatus() const { return m_status; }
    int loopStatus() const { return m_loop; }
    void setLoopStatus(int status);
    int shuffle() const { return m_shuffle; }
    void setShuffle(int value);
    double volume() const { return m_volume; }
    void setVolume(double v);
    bool canSeek() const { return m_canSeek; }
    bool canGoNext() const { return m_canGoNext; }
    bool canGoPrevious() const { return m_canGoPrevious; }
    bool canPlay() const { return m_canPlay; }
    bool canPause() const { return m_canPause; }
    bool canControl() const { return m_canControl; }
    bool canRaise() const { return m_canRaise; }

    Q_INVOKABLE void PlayPause();
    Q_INVOKABLE void Play();
    Q_INVOKABLE void Pause();
    Q_INVOKABLE void Stop();
    Q_INVOKABLE void Next();
    Q_INVOKABLE void Previous();
    Q_INVOKABLE void Raise();
    Q_INVOKABLE void Seek(double offsetUs);
    // Asks the player where it is now; the position otherwise runs on from the last report.
    Q_INVOKABLE void updatePosition();
    // Reads the player's position without taking it; the answer comes as positionRead, and only if
    // the song is still the one playing when it was asked.
    Q_INVOKABLE void askPosition();

Q_SIGNALS:
    void identityChanged();
    void desktopEntryChanged();
    void trackChanged();
    void artistChanged();
    void albumChanged();
    void artUrlChanged();
    void lengthChanged();
    void positionChanged();
    // Microseconds, the answer to askPosition.
    void positionRead(double position);
    void rateChanged();
    void playbackStatusChanged();
    void loopStatusChanged();
    void shuffleChanged();
    void volumeChanged();
    void capsChanged();

private Q_SLOTS:
    void onPropertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &invalidated);
    void onSeeked(qlonglong position);

private:
    void fetchAll();
    void apply(const QString &iface, const QVariantMap &props);
    void applyMetadata(const QVariantMap &meta);
    void call(const QString &method, const QVariantList &args = {});
    void setProp(const QString &name, const QVariant &value);
    void setRawPosition(double us);

    QString m_service;
    QString m_identity, m_desktopEntry, m_iconName;
    QString m_track, m_artist, m_album, m_artUrl, m_trackId;
    double m_length = 0;
    double m_position = 0;
    qint64 m_positionAt = 0;
    double m_rate = 1.0;
    int m_status = Unknown;
    int m_loop = 0;
    int m_shuffle = 0;
    double m_volume = 0;
    bool m_canSeek = false, m_canGoNext = false, m_canGoPrevious = false, m_canPlay = false, m_canPause = false, m_canControl = false,
         m_canRaise = false;
};

// All MPRIS players on the session bus, as `list`.
class MprisPlayers : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList list READ list NOTIFY listChanged)

public:
    explicit MprisPlayers(QObject *parent = nullptr);

    QVariantList list() const;

Q_SIGNALS:
    void listChanged();

private Q_SLOTS:
    void onOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner);

private:
    void add(const QString &service);
    void remove(const QString &service);

    QList<MprisPlayer *> m_players;
};
