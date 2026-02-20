/**
 * Snow — Weekly snowfall forecast for Swiss ski resorts.
 * Uses Open-Meteo multi-location API (single request for all resorts).
 */

export const VERSION = '1.0.0';

import { getWeatherDescription } from './weather.js';

const RESORTS = [
  { id: 'zermatt', name: 'Zermatt', nameDE: 'Zermatt', lat: 46.0207, lon: 7.7491, region: 'Valais', regionDE: 'Wallis', driveMinutes: 195, altitude: 1620 },
  { id: 'verbier', name: 'Verbier', nameDE: 'Verbier', lat: 46.0967, lon: 7.2286, region: 'Valais', regionDE: 'Wallis', driveMinutes: 170, altitude: 1500 },
  { id: 'saas-fee', name: 'Saas-Fee', nameDE: 'Saas-Fee', lat: 46.1048, lon: 7.9329, region: 'Valais', regionDE: 'Wallis', driveMinutes: 185, altitude: 1800 },
  { id: 'crans-montana', name: 'Crans-Montana', nameDE: 'Crans-Montana', lat: 46.3072, lon: 7.4816, region: 'Valais', regionDE: 'Wallis', driveMinutes: 175, altitude: 1500 },
  { id: 'nendaz', name: 'Nendaz', nameDE: 'Nendaz', lat: 46.1871, lon: 7.3041, region: 'Valais', regionDE: 'Wallis', driveMinutes: 165, altitude: 1400 },
  { id: 'davos', name: 'Davos', nameDE: 'Davos', lat: 46.8027, lon: 9.8360, region: 'Graubunden', regionDE: 'Graubünden', driveMinutes: 115, altitude: 1560 },
  { id: 'stmoritz', name: 'St. Moritz', nameDE: 'St. Moritz', lat: 46.4908, lon: 9.8355, region: 'Graubunden', regionDE: 'Graubünden', driveMinutes: 150, altitude: 1822 },
  { id: 'laax', name: 'Laax', nameDE: 'Laax', lat: 46.8097, lon: 9.2579, region: 'Graubunden', regionDE: 'Graubünden', driveMinutes: 100, altitude: 1100 },
  { id: 'arosa', name: 'Arosa', nameDE: 'Arosa', lat: 46.7832, lon: 9.6780, region: 'Graubunden', regionDE: 'Graubünden', driveMinutes: 110, altitude: 1775 },
  { id: 'lenzerheide', name: 'Lenzerheide', nameDE: 'Lenzerheide', lat: 46.7394, lon: 9.5584, region: 'Graubunden', regionDE: 'Graubünden', driveMinutes: 95, altitude: 1473 },
  { id: 'klosters', name: 'Klosters', nameDE: 'Klosters', lat: 46.8683, lon: 9.8756, region: 'Graubunden', regionDE: 'Graubünden', driveMinutes: 110, altitude: 1191 },
  { id: 'grindelwald', name: 'Grindelwald', nameDE: 'Grindelwald', lat: 46.6244, lon: 8.0413, region: 'Bernese Oberland', regionDE: 'Berner Oberland', driveMinutes: 130, altitude: 1034 },
  { id: 'wengen', name: 'Wengen', nameDE: 'Wengen', lat: 46.6082, lon: 7.9222, region: 'Bernese Oberland', regionDE: 'Berner Oberland', driveMinutes: 140, altitude: 1274 },
  { id: 'adelboden', name: 'Adelboden', nameDE: 'Adelboden', lat: 46.4917, lon: 7.5611, region: 'Bernese Oberland', regionDE: 'Berner Oberland', driveMinutes: 125, altitude: 1353 },
  { id: 'gstaad', name: 'Gstaad', nameDE: 'Gstaad', lat: 46.4750, lon: 7.2861, region: 'Bernese Oberland', regionDE: 'Berner Oberland', driveMinutes: 145, altitude: 1050 },
  { id: 'engelberg', name: 'Engelberg', nameDE: 'Engelberg', lat: 46.8210, lon: 8.4013, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 65, altitude: 1000 },
  { id: 'andermatt', name: 'Andermatt', nameDE: 'Andermatt', lat: 46.6343, lon: 8.5936, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 85, altitude: 1444 },
  { id: 'stoos', name: 'Stoos', nameDE: 'Stoos', lat: 46.9767, lon: 8.6625, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 55, altitude: 1300 },
  { id: 'flumserberg', name: 'Flumserberg', nameDE: 'Flumserberg', lat: 47.0912, lon: 9.2739, region: 'Eastern Switzerland', regionDE: 'Ostschweiz', driveMinutes: 60, altitude: 1220 },
  { id: 'hoch-ybrig', name: 'Hoch-Ybrig', nameDE: 'Hoch-Ybrig', lat: 47.0310, lon: 8.7890, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 50, altitude: 1100 },
  { id: 'braunwald', name: 'Braunwald', nameDE: 'Braunwald', lat: 46.9412, lon: 8.9998, region: 'Eastern Switzerland', regionDE: 'Ostschweiz', driveMinutes: 70, altitude: 1256 },
  { id: 'sattel-hochstuckli', name: 'Sattel-Hochstuckli', nameDE: 'Sattel-Hochstuckli', lat: 47.0800, lon: 8.6300, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 40, altitude: 1170 },
];

function getWeekDates() {
  const now = new Date();
  const day = now.getDay(); // 0=Sun..6=Sat
  const monday = new Date(now);
  monday.setDate(now.getDate() - ((day + 6) % 7)); // go back to Monday
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  const fmt = d => d.toISOString().split('T')[0];
  return { monday: fmt(monday), sunday: fmt(sunday) };
}

function parseLocationData(locData) {
  if (!locData.daily?.time) return null;

  const daily = locData.daily;
  const forecast = daily.time.map((date, i) => ({
    date,
    snowfallCm: Math.round((daily.snowfall_sum[i] || 0) * 10) / 10,
    weatherCode: daily.weather_code[i],
    tempMax: daily.temperature_2m_max[i] != null ? Math.round(daily.temperature_2m_max[i]) : 0,
    tempMin: daily.temperature_2m_min[i] != null ? Math.round(daily.temperature_2m_min[i]) : 0,
    description: getWeatherDescription(daily.weather_code[i]),
  }));

  const snowfallWeekTotal = Math.round(forecast.reduce((sum, d) => sum + d.snowfallCm, 0) * 10) / 10;

  // Get max snow depth from hourly data
  let snowDepthCm = 0;
  if (locData.hourly?.snow_depth) {
    const maxDepth = Math.max(...locData.hourly.snow_depth.filter(v => v != null));
    if (isFinite(maxDepth)) snowDepthCm = Math.round(maxDepth * 100); // meters to cm
  }

  return { forecast, snowfallWeekTotal, snowDepthCm };
}

async function fetchAllResorts(weekDates) {
  const lats = RESORTS.map(d => d.lat).join(',');
  const lons = RESORTS.map(d => d.lon).join(',');

  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lats}&longitude=${lons}&daily=snowfall_sum,weather_code,temperature_2m_max,temperature_2m_min&hourly=snow_depth&start_date=${weekDates.monday}&end_date=${weekDates.sunday}&timezone=Europe/Zurich`;

  const res = await fetch(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) {
    console.error(`Snow fetch failed: ${res.status}`);
    return [];
  }

  const data = await res.json();
  const locations = Array.isArray(data) ? data : [data];

  const results = [];
  for (let i = 0; i < RESORTS.length && i < locations.length; i++) {
    const parsed = parseLocationData(locations[i]);
    if (!parsed) continue;

    results.push({
      ...RESORTS[i],
      forecast: parsed.forecast,
      snowfallWeekTotal: parsed.snowfallWeekTotal,
      snowDepthCm: parsed.snowDepthCm,
    });
  }

  results.sort((a, b) => b.snowfallWeekTotal - a.snowfallWeekTotal);
  return results;
}

export async function handleSnow(url, env) {
  const lang = url.searchParams.get('lang') || 'en';
  const cacheKey = `snow-v1-${lang}`;

  // Check CF cache
  const cacheUrl = new URL(url.href);
  cacheUrl.searchParams.set('_ck', cacheKey);
  const cacheReq = new Request(cacheUrl.toString());
  const cfCache = caches.default;
  let cached = await cfCache.match(cacheReq);
  if (cached && url.searchParams.get('refresh') !== 'true') return cached;

  const weekDates = getWeekDates();
  const destinations = await fetchAllResorts(weekDates);

  const body = JSON.stringify({
    destinations,
    weekDates,
    timestamp: new Date().toISOString(),
  });

  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
    'Cache-Control': destinations.length > 0 ? 'public, max-age=1800' : 'no-store',
  };

  const response = new Response(body, { headers });

  if (destinations.length > 0) {
    await cfCache.put(cacheReq, new Response(body, { headers }));
  }

  return response;
}
