import QtQuick
import "weather.js" as W

QtObject {
    id: source

    // {latitude, longitude, city} from the config file, or null to locate by IP.
    property var override: null
    property bool fahrenheit: false
    property bool autoRefresh: true
    property var fetch: function(url, done) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (xhr.status !== 200) {
                done("HTTP " + xhr.status, null)
                return
            }
            try {
                done(null, JSON.parse(xhr.responseText))
            } catch (e) {
                done(String(e), null)
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    property bool ok: false
    property real temperature: NaN
    property real high: NaN
    property real low: NaN
    property int code: -1
    property string city: ""
    // [{hour: "17", temperature: 31}, ...] for the next 5 hours.
    property var hours: []
    readonly property bool retryScheduled: retry.running

    onOverrideChanged: refresh()
    onFahrenheitChanged: refresh()

    function refresh() {
        if (override) {
            loadForecast(override.latitude, override.longitude, override.city)
            return
        }
        fetch("https://get.geojs.io/v1/ip/geo.json", function(err, geo) {
            if (err || !geo) {
                failed()
                return
            }
            loadForecast(Number(geo.latitude), Number(geo.longitude), geo.city || "")
        })
    }

    function loadForecast(lat, lon, place) {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
                  + "&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1&hourly=temperature_2m&forecast_hours=6"
                  + (fahrenheit ? "&temperature_unit=fahrenheit" : "")
        fetch(url, function(err, data) {
            if (err || !data || !data.current || !data.daily) {
                failed()
                return
            }
            temperature = Math.round(data.current.temperature_2m)
            code = data.current.weather_code
            high = Math.round(data.daily.temperature_2m_max[0])
            low = Math.round(data.daily.temperature_2m_min[0])
            hours = W.nextHours(data.hourly, 5)
            city = place
            ok = true
            retry.stop()
        })
    }

    function failed() {
        ok = false
        if (!retry.running)
            retry.start()
    }

    // One quick retry after a failure (e.g. Wi-Fi still connecting after login).
    property Timer retry: Timer {
        interval: 60000
        onTriggered: source.refresh()
    }

    property Timer refresher: Timer {
        interval: 30 * 60 * 1000
        repeat: true
        triggeredOnStart: true
        running: source.autoRefresh
        onTriggered: source.refresh()
    }
}
