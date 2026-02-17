/**
 * Sunshine — Weekend sunshine forecast for destinations near Zurich.
 * Uses Open-Meteo multi-location API (single request for all destinations).
 */

export const VERSION = '1.1.0';

import { getWeatherDescription } from './weather.js';

const DESTINATIONS = [
  // Baseline (Zürich — always pinned first)
  { id: 'zurich', name: 'Zürich', nameDE: 'Zürich', lat: 47.3769, lon: 8.5417, region: 'Zürich', regionDE: 'Zürich', driveMinutes: 0, isBaseline: true },

  // Ticino
  { id: 'lugano', name: 'Lugano', nameDE: 'Lugano', lat: 46.0037, lon: 8.9511, region: 'Ticino', regionDE: 'Tessin', driveMinutes: 150 },
  { id: 'locarno', name: 'Locarno', nameDE: 'Locarno', lat: 46.1711, lon: 8.7953, region: 'Ticino', regionDE: 'Tessin', driveMinutes: 160 },
  { id: 'bellinzona', name: 'Bellinzona', nameDE: 'Bellinzona', lat: 46.1955, lon: 9.0234, region: 'Ticino', regionDE: 'Tessin', driveMinutes: 140 },
  { id: 'ascona', name: 'Ascona', nameDE: 'Ascona', lat: 46.1570, lon: 8.7726, region: 'Ticino', regionDE: 'Tessin', driveMinutes: 165 },

  // Graubunden
  { id: 'chur', name: 'Chur', nameDE: 'Chur', lat: 46.8499, lon: 9.5329, region: 'Graubünden', regionDE: 'Graubünden', driveMinutes: 80 },
  { id: 'davos', name: 'Davos', nameDE: 'Davos', lat: 46.8027, lon: 9.8360, region: 'Graubünden', regionDE: 'Graubünden', driveMinutes: 115 },
  { id: 'stmoritz', name: 'St. Moritz', nameDE: 'St. Moritz', lat: 46.4908, lon: 9.8355, region: 'Graubünden', regionDE: 'Graubünden', driveMinutes: 150 },
  { id: 'flims', name: 'Flims', nameDE: 'Flims', lat: 46.8354, lon: 9.2836, region: 'Graubünden', regionDE: 'Graubünden', driveMinutes: 95 },

  // Valais
  { id: 'sion', name: 'Sion', nameDE: 'Sitten', lat: 46.2330, lon: 7.3597, region: 'Valais', regionDE: 'Wallis', driveMinutes: 165 },
  { id: 'brig', name: 'Brig', nameDE: 'Brig', lat: 46.3138, lon: 7.9877, region: 'Valais', regionDE: 'Wallis', driveMinutes: 140 },
  { id: 'zermatt', name: 'Zermatt', nameDE: 'Zermatt', lat: 46.0207, lon: 7.7491, region: 'Valais', regionDE: 'Wallis', driveMinutes: 195 },

  // Central Switzerland
  { id: 'luzern', name: 'Lucerne', nameDE: 'Luzern', lat: 47.0502, lon: 8.3093, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 45 },
  { id: 'interlaken', name: 'Interlaken', nameDE: 'Interlaken', lat: 46.6863, lon: 7.8632, region: 'Bernese Oberland', regionDE: 'Berner Oberland', driveMinutes: 110 },
  { id: 'engelberg', name: 'Engelberg', nameDE: 'Engelberg', lat: 46.8210, lon: 8.4013, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 65 },
  { id: 'schwyz', name: 'Schwyz', nameDE: 'Schwyz', lat: 47.0207, lon: 8.6571, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 40 },
  { id: 'altdorf', name: 'Altdorf', nameDE: 'Altdorf', lat: 46.8802, lon: 8.6441, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 50 },

  // Lake Geneva
  { id: 'lausanne', name: 'Lausanne', nameDE: 'Lausanne', lat: 46.5197, lon: 6.6323, region: 'Lake Geneva', regionDE: 'Genfersee', driveMinutes: 140 },
  { id: 'montreux', name: 'Montreux', nameDE: 'Montreux', lat: 46.4312, lon: 6.9107, region: 'Lake Geneva', regionDE: 'Genfersee', driveMinutes: 150 },
  { id: 'vevey', name: 'Vevey', nameDE: 'Vevey', lat: 46.4603, lon: 6.8412, region: 'Lake Geneva', regionDE: 'Genfersee', driveMinutes: 145 },

  // Basel / Jura
  { id: 'basel', name: 'Basel', nameDE: 'Basel', lat: 47.5596, lon: 7.5886, region: 'Northwestern Switzerland', regionDE: 'Nordwestschweiz', driveMinutes: 55 },
  { id: 'solothurn', name: 'Solothurn', nameDE: 'Solothurn', lat: 47.2088, lon: 7.5378, region: 'Northwestern Switzerland', regionDE: 'Nordwestschweiz', driveMinutes: 65 },
  { id: 'delemont', name: 'Delémont', nameDE: 'Delémont', lat: 47.3647, lon: 7.3462, region: 'Jura', regionDE: 'Jura', driveMinutes: 90 },

  // Nearby
  { id: 'konstanz', name: 'Konstanz', nameDE: 'Konstanz', lat: 47.6633, lon: 9.1753, region: 'Lake Constance', regionDE: 'Bodensee', driveMinutes: 50 },
  { id: 'lindau', name: 'Lindau', nameDE: 'Lindau', lat: 47.5460, lon: 9.6829, region: 'Lake Constance', regionDE: 'Bodensee', driveMinutes: 70 },
  { id: 'como', name: 'Como', nameDE: 'Como', lat: 45.8081, lon: 9.0852, region: 'Lake Como', regionDE: 'Comer See', driveMinutes: 155 },
  { id: 'schaffhausen', name: 'Schaffhausen', nameDE: 'Schaffhausen', lat: 47.6960, lon: 8.6342, region: 'Eastern Switzerland', regionDE: 'Ostschweiz', driveMinutes: 35 },
  { id: 'frauenfeld', name: 'Frauenfeld', nameDE: 'Frauenfeld', lat: 47.5535, lon: 8.8987, region: 'Eastern Switzerland', regionDE: 'Ostschweiz', driveMinutes: 30 },
  { id: 'rapperswil', name: 'Rapperswil', nameDE: 'Rapperswil', lat: 47.2267, lon: 8.8184, region: 'Lake Zurich', regionDE: 'Zürichsee', driveMinutes: 25 },
];

function getWeekendDates() {
  const now = new Date();
  const day = now.getDay(); // 0=Sun, 1=Mon, ... 5=Fri, 6=Sat

  let friday;
  if (day === 5) {
    friday = new Date(now);
  } else if (day === 6) {
    friday = new Date(now);
    friday.setDate(friday.getDate() - 1);
  } else if (day === 0) {
    friday = new Date(now);
    friday.setDate(friday.getDate() - 2);
  } else {
    friday = new Date(now);
    friday.setDate(friday.getDate() + (5 - day));
  }

  const sat = new Date(friday);
  sat.setDate(sat.getDate() + 1);
  const sun = new Date(friday);
  sun.setDate(sun.getDate() + 2);

  const fmt = d => d.toISOString().split('T')[0];
  return { friday: fmt(friday), saturday: fmt(sat), sunday: fmt(sun) };
}

function parseLocationData(locData, dates) {
  if (!locData.daily?.time) return null;

  // Build hourly sunshine lookup: date -> array of hours with sunshine
  const hourlyMap = {};
  if (locData.hourly?.time) {
    locData.hourly.time.forEach((t, i) => {
      const date = t.substring(0, 10);
      const hour = parseInt(t.substring(11, 13), 10);
      if (hour >= 6 && hour <= 20 && (locData.hourly.sunshine_duration[i] || 0) > 0) {
        if (!hourlyMap[date]) hourlyMap[date] = [];
        hourlyMap[date].push(hour);
      }
    });
  }

  const allDays = locData.daily.time.map((date, i) => ({
    date,
    weatherCode: locData.daily.weather_code[i],
    tempMax: locData.daily.temperature_2m_max[i] != null ? Math.round(locData.daily.temperature_2m_max[i]) : 0,
    tempMin: locData.daily.temperature_2m_min[i] != null ? Math.round(locData.daily.temperature_2m_min[i]) : 0,
    sunshineHours: Math.round((locData.daily.sunshine_duration[i] || 0) / 360) / 10,
    precipMm: Math.round((locData.daily.precipitation_sum[i] || 0) * 10) / 10,
    sunnyHours: hourlyMap[date] || [],
    description: getWeatherDescription(locData.daily.weather_code[i]),
  }));

  const forecast = allDays.filter(d => dates.includes(d.date));
  const sunshineHoursTotal = Math.round(forecast.reduce((sum, d) => sum + d.sunshineHours, 0) * 10) / 10;

  return { forecast, sunshineHoursTotal };
}

async function fetchAllDestinations(weekendDates) {
  const lats = DESTINATIONS.map(d => d.lat).join(',');
  const lons = DESTINATIONS.map(d => d.lon).join(',');
  const dates = [weekendDates.friday, weekendDates.saturday, weekendDates.sunday];

  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lats}&longitude=${lons}&daily=weather_code,temperature_2m_max,temperature_2m_min,sunshine_duration,precipitation_sum&hourly=sunshine_duration&start_date=${weekendDates.friday}&end_date=${weekendDates.sunday}&timezone=Europe/Zurich`;

  const res = await fetch(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) {
    console.error(`Sunshine fetch failed: ${res.status}`);
    return [];
  }

  const data = await res.json();

  // Multi-location returns an array; single location returns a single object
  const locations = Array.isArray(data) ? data : [data];

  const results = [];
  for (let i = 0; i < DESTINATIONS.length && i < locations.length; i++) {
    const parsed = parseLocationData(locations[i], dates);
    if (!parsed) continue;

    results.push({
      ...DESTINATIONS[i],
      forecast: parsed.forecast,
      sunshineHoursTotal: parsed.sunshineHoursTotal,
    });
  }

  results.sort((a, b) => {
    if (a.isBaseline) return -1;
    if (b.isBaseline) return 1;
    return b.sunshineHoursTotal - a.sunshineHoursTotal;
  });
  return results;
}

export async function handleSunshine(url, env) {
  const lang = url.searchParams.get('lang') || 'en';
  const cacheKey = `sunshine-v3-${lang}`;

  // Check CF cache
  const cacheUrl = new URL(url.href);
  cacheUrl.searchParams.set('_ck', cacheKey);
  const cacheReq = new Request(cacheUrl.toString());
  const cfCache = caches.default;
  let cached = await cfCache.match(cacheReq);
  if (cached && !url.searchParams.has('refresh')) return cached;

  const weekendDates = getWeekendDates();
  const destinations = await fetchAllDestinations(weekendDates);

  const body = JSON.stringify({
    destinations,
    weekendDates,
    timestamp: new Date().toISOString(),
  });

  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
    'Cache-Control': destinations.length > 0 ? 'public, max-age=1800' : 'no-store',
  };

  const response = new Response(body, { headers });

  // Only cache successful (non-empty) responses
  if (destinations.length > 0) {
    await cfCache.put(cacheReq, new Response(body, { headers }));
  }

  return response;
}
