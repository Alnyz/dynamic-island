.pragma library

// WMO weather interpretation codes, as returned by Open-Meteo.
function describe(code) {
    if (code === 0) return { text: "Clear", icon: "weather-clear" }
    if (code === 1 || code === 2) return { text: "Partly cloudy", icon: "weather-few-clouds" }
    if (code === 3) return { text: "Cloudy", icon: "weather-overcast" }
    if (code === 45 || code === 48) return { text: "Fog", icon: "weather-fog" }
    if (code >= 51 && code <= 57) return { text: "Drizzle", icon: "weather-showers-scattered" }
    if (code >= 61 && code <= 67) return { text: "Rain", icon: "weather-showers" }
    if (code >= 71 && code <= 77) return { text: "Snow", icon: "weather-snow" }
    if (code >= 80 && code <= 82) return { text: "Showers", icon: "weather-showers" }
    if (code >= 95 && code <= 99) return { text: "Thunderstorm", icon: "weather-storm" }
    return { text: "", icon: "weather-none-available" }
}

// Open-Meteo's hourly forecast starts at the current hour; the next `count` hours follow it.
function nextHours(hourly, count) {
    if (!hourly || !hourly.time || !hourly.temperature_2m)
        return []
    const out = []
    for (let i = 1; i <= count && i < hourly.time.length; ++i)
        out.push({ hour: hourly.time[i].slice(11, 13), temperature: Math.round(hourly.temperature_2m[i]) })
    return out
}

// Reverse geocoding for an IP location that came without a city (BigDataCloud's keyless lookup).
function placeUrl(lat, lon) {
    return "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=" + lat + "&longitude=" + lon + "&localityLanguage=en"
}

// The best name for a place: the lookup's city or locality, else the IP location's region or country.
function placeName(place, geo) {
    const p = place || {}
    const g = geo || {}
    return p.city || p.locality || g.region || p.principalSubdivision || g.country || p.countryName || ""
}

// A full forecast (hourly and ten days) for a spot, to open in the browser.
function forecastUrl(lat, lon) {
    return "https://weather.com/weather/tenday/l/" + lat.toFixed(2) + "," + lon.toFixed(2)
}
