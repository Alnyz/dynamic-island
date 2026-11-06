#include "calendarsource.h"

#include <KCalendarCore/ICalFormat>
#include <KCalendarCore/MemoryCalendar>
#include <KCalendarCore/OccurrenceIterator>
#include <QFutureWatcher>
#include <QNetworkAccessManager>
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QtConcurrent/QtConcurrentRun>
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

CalendarSource::Parsed CalendarSource::parse(const QByteArray &icsDoc)
{
    auto calendar = KCalendarCore::MemoryCalendar::Ptr::create(QTimeZone::systemTimeZone());
    KCalendarCore::ICalFormat format;
    if (!format.fromRawString(calendar, icsDoc))
        return Parsed();
    // Parsed on a pool thread but read and deleted on the main one, so it has to belong there.
    if (auto *app = QCoreApplication::instance())
        calendar->moveToThread(app->thread());
    return calendar;
}

QList<CalendarSource::Occurrence> CalendarSource::expand(const QList<QByteArray> &icsDocs, const QDateTime &from, const QDateTime &to)
{
    QList<Parsed> calendars;
    for (const auto &doc : icsDocs)
        calendars.append(parse(doc));
    return expand(calendars, from, to);
}

QList<CalendarSource::Occurrence> CalendarSource::expand(const QList<Parsed> &calendars, const QDateTime &from, const QDateTime &to)
{
    QList<Occurrence> out;
    for (const auto &calendar : calendars) {
        if (!calendar)
            continue;
        KCalendarCore::OccurrenceIterator it(*calendar, from, to);
        while (it.hasNext()) {
            it.next();
            const auto incidence = it.incidence();
            if (incidence->type() != KCalendarCore::IncidenceBase::TypeEvent || incidence->status() == KCalendarCore::Incidence::StatusCanceled)
                continue;
            const QString link = meetingLink(incidence->location() + QLatin1Char(' ') + incidence->description() + QLatin1Char(' ') + incidence->url().toString());
            const QString note = incidence->description().section(QLatin1Char('\n'), 0, 0).trimmed().left(60);
            out.append({incidence->summary(), it.occurrenceStartDate(), it.occurrenceEndDate(), incidence->allDay(), link, note});
        }
    }
    std::sort(out.begin(), out.end(), [](const Occurrence &a, const Occurrence &b) {
        return a.start < b.start;
    });
    return out;
}

QList<CalendarSource::Occurrence> CalendarSource::upcoming(const QList<QByteArray> &icsDocs, const QDateTime &now, int count)
{
    QList<Parsed> calendars;
    for (const auto &doc : icsDocs)
        calendars.append(parse(doc));
    return upcoming(calendars, now, count);
}

QList<CalendarSource::Occurrence> CalendarSource::upcoming(const QList<Parsed> &calendars, const QDateTime &now, int count)
{
    auto occ = expand(calendars, now.date().startOfDay(), now.date().addDays(2).startOfDay());
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
    m_hashes.clear();
    m_parsed.clear();
    // Whatever is still on its way belongs to the old links and no longer counts.
    ++m_generation;
    m_pending = 0;
    m_parsing = 0;
    Q_EMIT changed();
    refresh();
}

void CalendarSource::refresh()
{
    if (m_urls.isEmpty() || m_pending > 0 || m_parsing > 0)
        return;
    const int generation = m_generation;
    m_lastAttempt = QDateTime::currentDateTime();
    m_pending = m_urls.size();
    m_roundFailed = false;
    for (const auto &url : std::as_const(m_urls)) {
        auto *reply = m_net->get(QNetworkRequest(QUrl(url)));
        connect(reply, &QNetworkReply::finished, this, [this, reply, url, generation] {
            reply->deleteLater();
            if (generation != m_generation)
                return;
            // Never log the URL: it is a secret link.
            if (reply->error() == QNetworkReply::NoError) {
                const QByteArray doc = reply->readAll();
                // The same file as the last good one (the usual case) needs no new parse.
                const QByteArray hash = QCryptographicHash::hash(doc, QCryptographicHash::Sha256);
                if (hash != m_hashes.value(url) || !m_parsed.contains(url))
                    parseLater(url, doc, hash);
            } else
                m_roundFailed = true;
            --m_pending;
            finishRound();
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
            {QStringLiteral("note"), o.note},
        });
    }
    return out;
}

void CalendarSource::finishRound()
{
    if (m_pending > 0 || m_parsing > 0)
        return;
    m_ok = !m_roundFailed;
    m_loaded = true;
    if (m_ok)
        m_lastSuccess = QDateTime::currentDateTime();
    else if (!m_retry.isActive())
        m_retry.start();
    Q_EMIT changed();
}

void CalendarSource::parseLater(const QString &url, const QByteArray &doc, const QByteArray &hash)
{
    const int generation = m_generation;
    ++m_parsing;
    auto *watcher = new QFutureWatcher<Parsed>(this);
    connect(watcher, &QFutureWatcher<Parsed>::finished, this, [this, watcher, url, hash, generation] {
        watcher->deleteLater();
        if (generation != m_generation)
            return;
        --m_parsing;
        // Not iCal (a sign-in page instead of the calendar, say): a failed round, and the last
        // good calendar stays.
        if (const Parsed calendar = watcher->result()) {
            m_parsed.insert(url, calendar);
            m_hashes.insert(url, hash);
        } else {
            m_roundFailed = true;
        }
        finishRound();
    });
    watcher->setFuture(QtConcurrent::run(&CalendarSource::parse, doc));
}

QList<CalendarSource::Occurrence> CalendarSource::forDays(const QList<Occurrence> &occ, QDate from, QDate to)
{
    const QDateTime start = from.startOfDay();
    const QDateTime end = to.addDays(1).startOfDay();
    QList<Occurrence> out;
    for (const auto &o : occ) {
        // All-day events end at 00:00 of their last day, so they're compared by date, last day included.
        const bool on = o.allDay ? o.start.date() <= to && qMax(o.end.date(), o.start.date()) >= from
                                 : o.start < end && (o.end > start || (o.end == o.start && o.start >= start));
        if (on)
            out.append(o);
    }
    return out;
}

QVariantList CalendarSource::occurrences(QDate from, QDate to) const
{
    return toVariant(forDays(expand(m_parsed.values(), from.startOfDay(), to.addDays(1).startOfDay()), from, to));
}

QVariantList CalendarSource::upNext(int count) const
{
    return toVariant(upcoming(m_parsed.values(), QDateTime::currentDateTime(), count));
}
