#pragma once

#include <KCalendarCore/MemoryCalendar>
#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <qqmlintegration.h>

class QNetworkAccessManager;

class CalendarSource : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QStringList urls READ urls WRITE setUrls NOTIFY changed)
    Q_PROPERTY(bool configured READ isConfigured NOTIFY changed)
    Q_PROPERTY(bool ok READ isOk NOTIFY changed)
    // False until the first download round has finished (success or not).
    Q_PROPERTY(bool loaded READ isLoaded NOTIFY changed)
    Q_PROPERTY(QDateTime lastSuccess READ lastSuccess NOTIFY changed)
    Q_PROPERTY(int refreshMinutes READ refreshMinutes WRITE setRefreshMinutes NOTIFY changed)

public:
    struct Occurrence {
        QString title;
        QDateTime start;
        QDateTime end;
        bool allDay = false;
        // Google Meet, Zoom or Teams link found in the event, if any.
        QString link;
        // The description's first line, short ("Public holiday" or "Observance" in Google's holiday calendars).
        QString note;
    };

    explicit CalendarSource(QObject *parent = nullptr);

    static QString meetingLink(const QString &text);
    using Parsed = KCalendarCore::MemoryCalendar::Ptr;
    // One iCal document, parsed (null when it isn't valid iCal). The slow part: done once per
    // download, off the main thread, never on a lookup.
    static Parsed parse(const QByteArray &icsDoc);
    static QList<Occurrence> expand(const QList<Parsed> &calendars, const QDateTime &from, const QDateTime &to);
    static QList<Occurrence> expand(const QList<QByteArray> &icsDocs, const QDateTime &from, const QDateTime &to);
    // Only the occurrences that fall on the days from..to: the expansion also returns events that
    // just touch the range's edges, like the next day's all-day holiday starting at midnight.
    static QList<Occurrence> forDays(const QList<Occurrence> &occ, QDate from, QDate to);
    // Not-yet-ended events from the start of today to the end of tomorrow.
    static QList<Occurrence> upcoming(const QList<Parsed> &calendars, const QDateTime &now, int count);
    static QList<Occurrence> upcoming(const QList<QByteArray> &icsDocs, const QDateTime &now, int count);

    QStringList urls() const { return m_urls; }
    void setUrls(const QStringList &urls);
    bool isConfigured() const { return !m_urls.isEmpty(); }
    bool isOk() const { return m_ok; }
    bool isLoaded() const { return m_loaded; }
    void setTransferTimeout(int ms);
    QDateTime lastSuccess() const { return m_lastSuccess; }
    int refreshMinutes() const { return m_timer.interval() / 60000; }
    void setRefreshMinutes(int minutes);

    Q_INVOKABLE QVariantList occurrences(QDate from, QDate to) const;
    Q_INVOKABLE QVariantList upNext(int count) const;
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshIfStale();

Q_SIGNALS:
    void changed();

private:
    QVariantList toVariant(const QList<Occurrence> &occ) const;

    QNetworkAccessManager *m_net;
    QStringList m_urls;
    // Last good download per link, parsed, kept when a later fetch fails, and its fingerprint.
    QHash<QString, QByteArray> m_hashes;
    QHash<QString, Parsed> m_parsed;
    // Bumped when the links change, so a download or parse of an old link that ends late is dropped.
    int m_generation = 0;
    void parseLater(const QString &url, const QByteArray &doc, const QByteArray &hash);
    // A round ends once every download and every parse it started has finished.
    int m_parsing = 0;
    void finishRound();
    bool m_ok = false;
    bool m_loaded = false;
    int m_pending = 0;
    bool m_roundFailed = false;
    QDateTime m_lastSuccess;
    QDateTime m_lastAttempt;
    QTimer m_timer;
    QTimer m_retry;
};
