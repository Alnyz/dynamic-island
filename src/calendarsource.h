#pragma once

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
    };

    explicit CalendarSource(QObject *parent = nullptr);

    static QString meetingLink(const QString &text);
    static QList<Occurrence> expand(const QList<QByteArray> &icsDocs, const QDateTime &from, const QDateTime &to);
    // Not-yet-ended events from the start of today to the end of tomorrow.
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
    // Last good download per link, kept when a later fetch fails.
    QHash<QString, QByteArray> m_docs;
    bool m_ok = false;
    bool m_loaded = false;
    int m_pending = 0;
    bool m_roundFailed = false;
    QDateTime m_lastSuccess;
    QDateTime m_lastAttempt;
    QTimer m_timer;
    QTimer m_retry;
};
