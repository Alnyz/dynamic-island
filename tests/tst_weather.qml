import QtQuick
import QtTest
import "../qml"
import "../qml/weather.js" as W

TestCase {
    id: tc
    name: "Weather"

    property var geo: ({ city: "Bandung", latitude: "-6.9", longitude: "107.6" })
    property var place: ({ city: "Chhindwara", locality: "Chhindwara", principalSubdivision: "Madhya Pradesh", countryName: "India" })
    readonly property var forecast: ({
        current: { temperature_2m: 28.6, weather_code: 2 },
        daily: { temperature_2m_max: [31.7], temperature_2m_min: [23.8] },
        hourly: { time: ["2026-10-23T16:00", "2026-10-23T17:00", "2026-10-23T18:00", "2026-10-23T19:00", "2026-10-23T20:00", "2026-10-23T21:00"],
                  temperature_2m: [31.2, 30.6, 29.4, 28.1, 27.5, 26.9] }
    })
    property var requested: []
    property bool failing: false

    function fakeFetch(url, done) {
        requested.push(url)
        if (failing)
            done("network down", null)
        else
            done(null, url.indexOf("geojs") >= 0 ? geo : url.indexOf("bigdatacloud") >= 0 ? place : forecast)
    }

    Component {
        id: sourceComp
        WeatherSource { fetch: tc.fakeFetch; autoRefresh: false }
    }

    function init() {
        requested = []
        failing = false
        geo = { city: "Bandung", latitude: "-6.9", longitude: "107.6" }
    }

    function test_city_from_coordinates_when_ip_has_none() {
        geo = { city: null, region: null, country: "India", latitude: "22.06", longitude: "78.94" }
        const source = createTemporaryObject(sourceComp, tc)
        source.refresh()
        compare(source.city, "Chhindwara")
        verify(requested.some(u => u.indexOf("bigdatacloud") >= 0 && u.indexOf("latitude=22.06") > 0))
    }

    function test_city_lookup_failing_falls_back_to_country() {
        geo = { city: null, region: null, country: "India", latitude: "22.06", longitude: "78.94" }
        const source = createTemporaryObject(sourceComp, tc)
        source.fetch = function(url, done) {
            if (url.indexOf("bigdatacloud") >= 0) done("down", null)
            else tc.fakeFetch(url, done)
        }
        source.refresh()
        compare(source.ok, true)
        compare(source.city, "India")
    }

    function test_no_city_lookup_when_ip_has_one() {
        const source = createTemporaryObject(sourceComp, tc)
        source.refresh()
        compare(source.city, "Bandung")
        compare(requested.some(u => u.indexOf("bigdatacloud") >= 0), false)
    }

    function test_forecast_link() {
        const source = createTemporaryObject(sourceComp, tc)
        compare(source.forecastUrl, "")
        source.refresh()
        compare(source.forecastUrl, "https://weather.com/weather/tenday/l/-6.90,107.60")
        compare(W.placeName({ locality: "Town" }, {}), "Town")
        compare(W.placeName(null, { region: "Java", country: "Indonesia" }), "Java")
        compare(W.placeName(null, null), "")
    }

    function test_describe_codes() {
        compare(W.describe(0).text, "Clear")
        compare(W.describe(2).text, "Partly cloudy")
        compare(W.describe(3).text, "Cloudy")
        compare(W.describe(63).text, "Rain")
        compare(W.describe(95).text, "Thunderstorm")
        compare(W.describe(95).icon, "weather-storm")
        compare(W.describe(1234).text, "")
    }

    function test_weather_parses() {
        const source = createTemporaryObject(sourceComp, tc)
        source.refresh()
        compare(source.ok, true)
        compare(source.temperature, 29)
        compare(source.high, 32)
        compare(source.low, 24)
        compare(source.code, 2)
        compare(source.city, "Bandung")
    }

    function test_weather_failure_keeps_last() {
        const source = createTemporaryObject(sourceComp, tc)
        source.refresh()
        failing = true
        source.refresh()
        compare(source.ok, false)
        compare(source.temperature, 29)
        compare(source.city, "Bandung")
    }

    function test_failure_schedules_retry() {
        const source = createTemporaryObject(sourceComp, tc)
        failing = true
        source.refresh()
        compare(source.retryScheduled, true)
        failing = false
        source.refresh()
        compare(source.retryScheduled, false)
    }

    function test_override_skips_geo() {
        const source = createTemporaryObject(sourceComp, tc, { override: { latitude: -7.25, longitude: 112.75, city: "Surabaya" } })
        source.refresh()
        compare(requested.some(u => u.indexOf("geojs") >= 0), false)
        compare(source.city, "Surabaya")
        verify(requested[0].indexOf("latitude=-7.25") >= 0)
    }

    function test_fahrenheit_asks_for_fahrenheit() {
        const source = createTemporaryObject(sourceComp, tc, { fahrenheit: true })
        source.refresh()
        verify(requested[requested.length - 1].indexOf("temperature_unit=fahrenheit") >= 0)
    }

    function test_changing_location_or_unit_refetches() {
        const source = createTemporaryObject(sourceComp, tc)
        source.refresh()
        const before = requested.length
        source.override = { latitude: 1, longitude: 2, city: "X" }
        compare(source.city, "X")
        source.fahrenheit = true
        compare(requested.length, before + 2)
    }

    function test_next_hours() {
        const source = createTemporaryObject(sourceComp, tc)
        source.refresh()
        compare(source.hours.length, 5)
        compare(source.hours[0].hour, "17")
        compare(source.hours[0].temperature, 31)
        compare(source.hours[4].hour, "21")
        verify(requested[requested.length - 1].indexOf("hourly=temperature_2m") >= 0)
    }

    function test_hours_missing_is_empty() {
        compare(W.nextHours(undefined, 5), [])
    }
}
