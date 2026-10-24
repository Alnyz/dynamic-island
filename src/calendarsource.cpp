#include "calendarsource.h"

#include <KCalendarCore/ICalFormat>
#include <KCalendarCore/MemoryCalendar>
#include <KCalendarCore/OccurrenceIterator>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QTimeZone>
#include <algorithm>

namespace
{
constexpr int kRefreshMs = 15 * 60 * 1000;
constexpr int kRetryMs = 60 * 1000;
// Opening the panel re-downloads after this, so a just-added event shows up.
constexpr int kOpenStaleMs = 60 * 1000;
constexpr int kTransferTimeoutMs = 30 * 1000;
}

CalendarSource::CalendarSource(QObject *parent)
    : QObject(parent)
    , m_net(new QNetworkAccessManager(this))
{
    m_net->setTransferTimeout(kTransferTimeoutMs);
    // One quick retry after a failed round (e.g. Wi-Fi still connecting after login).
    m_retry.setSingleShot(true);
    m_retry.setInterval(kRetryMs);
    connect(&m_retry, &QTimer::timeout, this, &CalendarSource::refresh);
    m_timer.setInterval(kRefreshMs);
    connect(&m_timer, &QTimer::timeout, this, &CalendarSource::refresh);
    m_timer.start();
}

QList<CalendarSource::Occurrence> CalendarSource::expand(const QList<QByteArray> &icsDocs, const QDateTime &from, const QDateTime &to)
{
    QList<Occurrence> out;
    for (const auto &doc : icsDocs) {
        auto calendar = KCalendarCore::MemoryCalendar::Ptr::create(QTimeZone::systemTimeZone());
        KCalendarCore::ICalFormat format;
        if (!format.fromRawString(calendar, doc))
            continue;
        KCalendarCore::OccurrenceIterator it(*calendar, from, to);
        while (it.hasNext()) {
            it.next();
            const auto incidence = it.incidence();
            if (incidence->type() != KCalendarCore::IncidenceBase::TypeEvent || incidence->status() == KCalendarCore::Incidence::StatusCanceled)
                continue;
            const QString link = meetingLink(incidence->location() + QLatin1Char(' ') + incidence->description() + QLatin1Char(' ') + incidence->url().toString());
            out.append({incidence->summary(), it.occurrenceStartDate(), it.occurrenceEndDate(), incidence->allDay(), link});
        }
    }
    std::sort(out.begin(), out.end(), [](const Occurrence &a, const Occurrence &b) {
        return a.start < b.start;
    });
    return out;
}

QList<CalendarSource::Occurrence> CalendarSource::upcoming(const QList<QByteArray> &icsDocs, const QDateTime &now, int count)
{
    auto occ = expand(icsDocs, now.date().startOfDay(), now.date().addDays(2).startOfDay());
    occ.erase(std::remove_if(occ.begin(), occ.end(),
                             [&now](const Occurrence &o) {
                                 // All-day events end at 00:00 of their last day; they last until the next midnight.
                                 const auto end = o.allDay ? o.end.date().addDays(1).startOfDay() : o.end;
                                 return end <= now;
                             }),
              occ.end());
    return occ.mid(0, count);
}

void CalendarSource::setRefreshMinutes(int minutes)
{
    if (minutes < 1 || minutes == refreshMinutes())
        return;
    m_timer.start(minutes * 60000);
    Q_EMIT changed();
}

void CalendarSource::setTransferTimeout(int ms)
{
    m_net->setTransferTimeout(ms);
}

void CalendarSource::setUrls(const QStringList &urls)
{
    if (urls == m_urls)
        return;
    m_urls = urls;
    m_docs.clear();
    Q_EMIT changed();
    refresh();
}

void CalendarSource::refresh()
{
    if (m_urls.isEmpty() || m_pending > 0)
        return;
    m_lastAttempt = QDateTime::currentDateTime();
    m_pending = m_urls.size();
    m_roundFailed = false;
    for (const auto &url : std::as_const(m_urls)) {
        auto *reply = m_net->get(QNetworkRequest(QUrl(url)));
        connect(reply, &QNetworkReply::finished, this, [this, reply, url] {
            reply->deleteLater();
            // Never log the URL: it is a secret link.
            if (reply->error() == QNetworkReply::NoError)
                m_docs.insert(url, reply->readAll());
            else
                m_roundFailed = true;
            if (--m_pending > 0)
                return;
            m_ok = !m_roundFailed;
            m_loaded = true;
            if (m_ok)
                m_lastSuccess = QDateTime::currentDateTime();
            else if (!m_retry.isActive())
                m_retry.start();
            Q_EMIT changed();
        });
    }
}

void CalendarSource::refreshIfStale()
{
    if (!m_ok || !m_lastAttempt.isValid() || m_lastAttempt.msecsTo(QDateTime::currentDateTime()) >= kOpenStaleMs)
        refresh();
}

QString CalendarSource::meetingLink(const QString &text)
{
    static const QRegularExpression re(QStringLiteral("https://(?:meet\\.google\\.com/|[\\w.-]*zoom\\.us/j/|teams\\.microsoft\\.com/l/meetup-join/)[^\\s<>\"]+"));
    return re.match(text).captured();
}

QVariantList CalendarSource::toVariant(const QList<Occurrence> &occ) const
{
    QVariantList out;
    for (const auto &o : occ) {
        out.append(QVariantMap{
            {QStringLiteral("title"), o.title},
            {QStringLiteral("start"), o.start},
            {QStringLiteral("end"), o.end},
            {QStringLiteral("allDay"), o.allDay},
            {QStringLiteral("link"), o.link},
        });
    }
    return out;
}

QVariantList CalendarSource::occurrences(QDate from, QDate to) const
{
    return toVariant(expand(m_docs.values(), from.startOfDay(), to.addDays(1).startOfDay()));
}

QVariantList CalendarSource::upNext(int count) const
{
    return toVariant(upcoming(m_docs.values(), QDateTime::currentDateTime(), count));
}
