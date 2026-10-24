#include "calendarsource.h"

#include <QSignalSpy>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QTest>

namespace
{
QByteArray ics(const QByteArray &events)
{
    return "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//test//EN\r\n" + events + "END:VCALENDAR\r\n";
}

const QDateTime kFrom(QDate(2026, 10, 1), QTime(0, 0), QTimeZone::UTC);
const QDateTime kTo(QDate(2026, 11, 1), QTime(0, 0), QTimeZone::UTC);

const QByteArray kSingle =
    "BEGIN:VEVENT\r\nUID:single@test\r\nDTSTART:20261023T080000Z\r\nDTEND:20261023T084500Z\r\nSUMMARY:Design review\r\nEND:VEVENT\r\n";
const QByteArray kAllDay =
    "BEGIN:VEVENT\r\nUID:allday@test\r\nDTSTART;VALUE=DATE:20261024\r\nDTEND;VALUE=DATE:20261025\r\nSUMMARY:Holiday\r\nEND:VEVENT\r\n";
}

class TestCalendar : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void testSingleEvent()
    {
        const auto occ = CalendarSource::expand({ics(kSingle)}, kFrom, kTo);
        QCOMPARE(occ.size(), 1);
        QCOMPARE(occ[0].title, QStringLiteral("Design review"));
        QCOMPARE(occ[0].start.toUTC(), QDateTime(QDate(2026, 10, 23), QTime(8, 0), QTimeZone::UTC));
        QCOMPARE(occ[0].end.toUTC(), QDateTime(QDate(2026, 10, 23), QTime(8, 45), QTimeZone::UTC));
        QCOMPARE(occ[0].allDay, false);
    }

    void testMeetingLink()
    {
        const QByteArray meet =
            "BEGIN:VEVENT\r\nUID:meet@test\r\nDTSTART:20261023T070000Z\r\nDTEND:20261023T084500Z\r\nSUMMARY:Sync\r\n"
            "DESCRIPTION:Agenda first.\\nJoin: https://meet.google.com/abc-defg-hij?authuser=0 thanks\r\nEND:VEVENT\r\n";
        const auto occ = CalendarSource::expand({ics(meet + kSingle)}, kFrom, kTo);
        QCOMPARE(occ[0].link, QStringLiteral("https://meet.google.com/abc-defg-hij?authuser=0"));
        QCOMPARE(occ[1].link, QString());
        QCOMPARE(CalendarSource::meetingLink(QStringLiteral("Room 4, https://us02web.zoom.us/j/123456?pwd=x")), QStringLiteral("https://us02web.zoom.us/j/123456?pwd=x"));
        QCOMPARE(CalendarSource::meetingLink(QStringLiteral("<https://teams.microsoft.com/l/meetup-join/19%3a>")), QStringLiteral("https://teams.microsoft.com/l/meetup-join/19%3a"));
        QCOMPARE(CalendarSource::meetingLink(QStringLiteral("https://example.com/meet")), QString());
    }

    void testAllDay()
    {
        const auto occ = CalendarSource::expand({ics(kAllDay)}, kFrom, kTo);
        QCOMPARE(occ.size(), 1);
        QCOMPARE(occ[0].allDay, true);
        QCOMPARE(occ[0].start.date(), QDate(2026, 10, 24));
    }

    void testWeeklyRecurring()
    {
        const QByteArray weekly =
            "BEGIN:VEVENT\r\nUID:gym@test\r\nDTSTART:20261005T100000Z\r\nDTEND:20261005T104500Z\r\n"
            "RRULE:FREQ=WEEKLY;COUNT=3\r\nSUMMARY:Gym\r\nEND:VEVENT\r\n";
        const auto occ = CalendarSource::expand({ics(weekly)}, kFrom, kTo);
        QCOMPARE(occ.size(), 3);
        QCOMPARE(occ[2].start.toUTC().date(), QDate(2026, 10, 19));
    }

    void testRecurringWithException()
    {
        const QByteArray events =
            "BEGIN:VEVENT\r\nUID:standup@test\r\nDTSTART:20261005T090000Z\r\nDTEND:20261005T091500Z\r\n"
            "RRULE:FREQ=WEEKLY;COUNT=4\r\nEXDATE:20261012T090000Z\r\nSUMMARY:Standup\r\nEND:VEVENT\r\n"
            "BEGIN:VEVENT\r\nUID:standup@test\r\nRECURRENCE-ID:20261019T090000Z\r\n"
            "DTSTART:20261020T100000Z\r\nDTEND:20261020T101500Z\r\nSUMMARY:Standup (moved)\r\nEND:VEVENT\r\n";
        const auto occ = CalendarSource::expand({ics(events)}, kFrom, kTo);
        QStringList starts;
        for (const auto &o : occ)
            starts << o.start.toUTC().toString(Qt::ISODate);
        QCOMPARE(starts,
                 QStringList({QStringLiteral("2026-10-05T09:00:00Z"), QStringLiteral("2026-10-20T10:00:00Z"), QStringLiteral("2026-10-26T09:00:00Z")}));
        QCOMPARE(occ[1].title, QStringLiteral("Standup (moved)"));
    }

    void testMergeTwoDocs()
    {
        const auto occ = CalendarSource::expand({ics(kSingle), ics(kAllDay)}, kFrom, kTo);
        QCOMPARE(occ.size(), 2);
        QVERIFY(occ[0].start <= occ[1].start);
    }

    void testCancelledSkipped()
    {
        const QByteArray events =
            "BEGIN:VEVENT\r\nUID:sync@test\r\nDTSTART:20261005T090000Z\r\nDTEND:20261005T091500Z\r\n"
            "RRULE:FREQ=WEEKLY;COUNT=2\r\nSUMMARY:1:1\r\nEND:VEVENT\r\n"
            "BEGIN:VEVENT\r\nUID:sync@test\r\nRECURRENCE-ID:20261012T090000Z\r\nSTATUS:CANCELLED\r\n"
            "DTSTART:20261012T090000Z\r\nDTEND:20261012T091500Z\r\nSUMMARY:1:1\r\nEND:VEVENT\r\n"
            "BEGIN:VEVENT\r\nUID:gone@test\r\nSTATUS:CANCELLED\r\nDTSTART:20261015T090000Z\r\n"
            "DTEND:20261015T100000Z\r\nSUMMARY:Gone\r\nEND:VEVENT\r\n";
        const auto occ = CalendarSource::expand({ics(events)}, kFrom, kTo);
        QCOMPARE(occ.size(), 1);
        QCOMPARE(occ[0].start.toUTC().date(), QDate(2026, 10, 5));
    }

    void testUpcomingIncludesAllDayToday()
    {
        const QDateTime now(QDate(2026, 10, 24), QTime(15, 0));
        const auto occ = CalendarSource::upcoming({ics(kAllDay + kSingle)}, now, 5);
        QCOMPARE(occ.size(), 1);
        QCOMPARE(occ[0].title, QStringLiteral("Holiday"));
    }

    void testUpcomingDropsEnded()
    {
        const QDateTime now(QDate(2026, 10, 23), QDateTime::fromString(QStringLiteral("2026-10-23T09:00:00Z"), Qt::ISODate).toLocalTime().time());
        const auto occ = CalendarSource::upcoming({ics(kSingle)}, QDateTime::fromString(QStringLiteral("2026-10-23T09:00:00Z"), Qt::ISODate), 5);
        QCOMPARE(occ.size(), 0);
        Q_UNUSED(now);
    }

    void testStuckDownloadTimesOut()
    {
        QTcpServer server;
        QVERIFY(server.listen(QHostAddress::LocalHost));
        QList<QTcpSocket *> held;
        connect(&server, &QTcpServer::newConnection, this, [&] { held << server.nextPendingConnection(); });

        CalendarSource source;
        source.setTransferTimeout(300);
        QSignalSpy spy(&source, &CalendarSource::changed);
        source.setUrls({QStringLiteral("http://127.0.0.1:%1/cal.ics").arg(server.serverPort())});
        QVERIFY(spy.wait(3000));
        while (source.isLoaded() == false && spy.wait(3000)) { }
        QCOMPARE(source.isLoaded(), true);
        QCOMPARE(source.isOk(), false);
    }

    void testLoadedAndStaleRetry()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("cal.ics"));
        CalendarSource source;
        QCOMPARE(source.isLoaded(), false);
        QSignalSpy spy(&source, &CalendarSource::changed);
        source.setUrls({QUrl::fromLocalFile(path).toString()});
        QVERIFY(spy.wait(3000));
        QCOMPARE(source.isOk(), false);

        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(ics(kSingle));
        file.close();
        // A failed round counts as stale, so opening the panel retries right away.
        source.refreshIfStale();
        QVERIFY(spy.wait(3000));
        QCOMPARE(source.isOk(), true);
    }

    void testFetchFailureKeepsEvents()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("cal.ics"));
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(ics(kSingle));
        file.close();

        CalendarSource source;
        QSignalSpy spy(&source, &CalendarSource::changed);
        source.setUrls({QUrl::fromLocalFile(path).toString()});
        source.refresh();
        QVERIFY(spy.wait(3000));
        QCOMPARE(source.isOk(), true);
        QCOMPARE(source.occurrences(QDate(2026, 10, 1), QDate(2026, 10, 31)).size(), 1);

        QFile::remove(path);
        source.refresh();
        QVERIFY(spy.wait(3000));
        QCOMPARE(source.isOk(), false);
        QCOMPARE(source.occurrences(QDate(2026, 10, 1), QDate(2026, 10, 31)).size(), 1);
    }
};

QTEST_GUILESS_MAIN(TestCalendar)
#include "tst_calendar.moc"
