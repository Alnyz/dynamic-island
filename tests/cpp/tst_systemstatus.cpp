#include "systemstatus.h"

#include <QTest>

class TestSystemStatus : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void testParseWpctl()
    {
        QCOMPARE(SystemStatus::parseWpctlVolume(QStringLiteral("Volume: 0.45\n")), std::make_optional(std::pair{45, false}));
        QCOMPARE(SystemStatus::parseWpctlVolume(QStringLiteral("Volume: 0.30 [MUTED]\n")), std::make_optional(std::pair{30, true}));
        QCOMPARE(SystemStatus::parseWpctlVolume(QStringLiteral("garbage")), std::nullopt);
    }

    void testChargerChangeIgnoresRoutineReadings()
    {
        // What a battery sends every few seconds, from a real laptop.
        QVERIFY(!SystemStatus::isChargerChange({{QStringLiteral("UpdateTime"), 1}, {QStringLiteral("EnergyRate"), 1.0}, {QStringLiteral("TimeToEmpty"), 1}, {QStringLiteral("Voltage"), 1.0}}));
        QVERIFY(SystemStatus::isChargerChange({{QStringLiteral("Online"), true}}));
        QVERIFY(SystemStatus::isChargerChange({{QStringLiteral("State"), 1}, {QStringLiteral("UpdateTime"), 1}}));
        QVERIFY(SystemStatus::isChargerChange({{QStringLiteral("OnBattery"), false}}));
    }

    void testParseNmcli()
    {
        QCOMPARE(SystemStatus::parseNmcliRadio(QStringLiteral("enabled\n")), true);
        QCOMPARE(SystemStatus::parseNmcliRadio(QStringLiteral("disabled\n")), false);
    }

    void testParseBluetooth()
    {
        const auto on = QStringLiteral("Controller 00:11:22:33:44:55 (public)\n\tName: laptop\n\tPowered: yes\n\tDiscoverable: no\n");
        const auto off = QStringLiteral("Controller 00:11:22:33:44:55 (public)\n\tPowered: no\n");
        QCOMPARE(SystemStatus::parseBluetoothPowered(on), true);
        QCOMPARE(SystemStatus::parseBluetoothPowered(off), false);
        QCOMPARE(SystemStatus::parseBluetoothPowered(QString()), false);
    }

    void testParseBattery()
    {
        QCOMPARE(SystemStatus::parseBattery(QStringLiteral("80\n"), QStringLiteral("Charging\n")), (std::pair{80, true}));
        QCOMPARE(SystemStatus::parseBattery(QStringLiteral("100\n"), QStringLiteral("Full\n")), (std::pair{100, true}));
        QCOMPARE(SystemStatus::parseBattery(QStringLiteral("37\n"), QStringLiteral("Discharging\n")), (std::pair{37, false}));
        QCOMPARE(SystemStatus::parseBattery(QStringLiteral("80\n"), QStringLiteral("Not charging\n")), (std::pair{80, true}));
    }

    void testMinutesLeft()
    {
        // 30 Wh left at 15 W: two hours.
        QCOMPARE(SystemStatus::minutesLeft(QStringLiteral("Discharging"), 30000000, 57000000, 15000000), 120);
        // 27 Wh to go at 54 W: half an hour.
        QCOMPARE(SystemStatus::minutesLeft(QStringLiteral("Charging\n"), 30000000, 57000000, 54000000), 30);
        // Some batteries report the current as negative while discharging.
        QCOMPARE(SystemStatus::minutesLeft(QStringLiteral("Discharging"), 4000000, 5000000, -2000000), 120);
        QCOMPARE(SystemStatus::minutesLeft(QStringLiteral("Full"), 57180000, 57180000, 0), -1);
        QCOMPARE(SystemStatus::minutesLeft(QStringLiteral("Not charging"), 50000000, 57000000, 1000000), -1);
        QCOMPARE(SystemStatus::minutesLeft(QStringLiteral("Discharging"), 30000000, 57000000, 0), -1);
        // A trickle that would take days isn't an estimate.
        QCOMPARE(SystemStatus::minutesLeft(QStringLiteral("Discharging"), 50000000, 57000000, 100000), -1);
    }

    void testPluggedIn()
    {
        using S = QList<std::pair<QString, bool>>;
        // Charger pulled while the battery still says "Charging": unplugged.
        QVERIFY(!SystemStatus::pluggedIn(S{{QStringLiteral("Mains"), false}, {QStringLiteral("Battery"), false}}, QStringLiteral("Charging")));
        // Plugged in while the battery still says "Discharging": plugged.
        QVERIFY(SystemStatus::pluggedIn(S{{QStringLiteral("Mains"), true}, {QStringLiteral("Battery"), false}}, QStringLiteral("Discharging")));
        // A USB-C charger counts.
        QVERIFY(SystemStatus::pluggedIn(S{{QStringLiteral("Mains"), false}, {QStringLiteral("USB"), true}}, QStringLiteral("Discharging")));
        // No charger listed at all: the battery's status decides.
        QVERIFY(SystemStatus::pluggedIn(S{{QStringLiteral("Battery"), false}}, QStringLiteral("Full")));
        QVERIFY(!SystemStatus::pluggedIn(S{}, QStringLiteral("Discharging\n")));
    }

    void testSilenced()
    {
        // Plasma holds notifications while a full-screen app is active; the island can look past
        // those holds, never past do not disturb the user switched on.
        QVERIFY(SystemStatus::silenced(false, false, true, false));
        QVERIFY(!SystemStatus::silenced(false, false, true, true));
        QVERIFY(SystemStatus::silenced(false, true, false, true));
        QVERIFY(SystemStatus::silenced(true, false, false, true));
        QVERIFY(!SystemStatus::silenced(false, false, false, false));
    }

    void testDndUntil()
    {
        const QDateTime now(QDate(2026, 10, 23), QTime(15, 0));
        QCOMPARE(SystemStatus::dndUntilActive(QStringLiteral("2026-10-23T16:00:00"), now), true);
        QCOMPARE(SystemStatus::dndUntilActive(QStringLiteral("2026-10-23T14:00:00"), now), false);
        QCOMPARE(SystemStatus::dndUntilActive(QString(), now), false);
    }
};

QTEST_GUILESS_MAIN(TestSystemStatus)
#include "tst_systemstatus.moc"
