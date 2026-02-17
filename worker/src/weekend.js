/**
 * Weekend Planner — smart activity filtering by weather and day-of-week.
 */

export const VERSION = '2.0.0';

import { getCity, getUpcomingHolidays } from './data.js';
import { fetchWeekendWeather, RAINY_CODES } from './weather.js';
import { getCuratedActivities } from './activities.js';

function isAvailableOnDate(activity, date) {
  if (activity.recurring) {
    const r = activity.recurring.toLowerCase();
    const dow = date.getDay();
    if (r === 'weekends' || r.includes('weekend')) return true;
    if (r.includes('various')) return true;
    const days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    if (r.includes(days[dow])) return true;
    if (days.some(d => r.includes(d))) return false;
    return false;
  }
  if (activity.availableMonths) return activity.availableMonths.includes(date.getMonth() + 1);
  return true;
}

function pickActivities(weather, all, targetDate, excludeIds) {
  let cands = all.filter(a => isAvailableOnDate(a, targetDate) && a.category !== 'stayhome');
  if (excludeIds?.length) {
    const without = cands.filter(a => !excludeIds.includes(a.id));
    if (without.length >= 2) cands = without;
  }
  if (weather) {
    const bad = RAINY_CODES.includes(weather.weatherCode) || weather.tempMax < 5;
    if (bad) { const indoor = cands.filter(a => a.indoor); if (indoor.length) cands = indoor; }
    else cands.sort((a, b) => (a.indoor ? 1 : -1) - (b.indoor ? 1 : -1));
  }
  // Shuffle
  for (let i = cands.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [cands[i], cands[j]] = [cands[j], cands[i]];
  }
  const short = ['30 min', '1 hour', '1-2 hours'];
  const shorts = cands.filter(a => short.includes(a.duration));
  const longs = cands.filter(a => !short.includes(a.duration));
  const morning = shorts[0] || cands[0] || null;
  const afternoon = longs.find(a => a.id !== morning?.id) || cands.find(a => a.id !== morning?.id) || null;
  return { morning, afternoon };
}

export async function handleWeekend(url, env) {
  const lang = url.searchParams.get('lang') || 'en';
  const cityId = url.searchParams.get('city') || 'zurich';
  const city = getCity(cityId);
  const forceRefresh = url.searchParams.get('refresh') === 'true';

  // CF cache
  let cache, cacheKey;
  try {
    cacheKey = new Request(`https://cache.local/weekend-${cityId}-${lang}`, { method: 'GET' });
    cache = caches.default;
    if (!forceRefresh) {
      const c = await cache.match(cacheKey);
      if (c) {
        const h = new Headers(c.headers);
        h.set('Access-Control-Allow-Origin', env.ALLOWED_ORIGIN || '*');
        h.set('X-Cache', 'HIT');
        return new Response(c.body, { headers: h });
      }
    }
  } catch {}

  const [weekendWeather, activities, holidays] = await Promise.all([
    fetchWeekendWeather(city.lat, city.lon),
    getCuratedActivities(env, cityId),
    Promise.resolve(getUpcomingHolidays(cityId))
  ]);

  const now = new Date();
  const dow = now.getDay();
  let daysUntilSat = (6 - dow) % 7;
  if (dow === 0) daysUntilSat = 6;

  const satDate = new Date(now); satDate.setDate(now.getDate() + daysUntilSat);
  const sunDate = new Date(satDate); sunDate.setDate(satDate.getDate() + 1);
  const satStr = satDate.toISOString().split('T')[0];
  const sunStr = sunDate.toISOString().split('T')[0];

  const satWeather = weekendWeather?.find(d => d.date === satStr) || null;
  const sunWeather = weekendWeather?.find(d => d.date === sunStr) || null;

  const satPlan = pickActivities(satWeather, activities, satDate, []);
  const satIds = [satPlan.morning?.id, satPlan.afternoon?.id].filter(Boolean);
  const sunPlan = pickActivities(sunWeather, activities, sunDate, satIds);

  const body = JSON.stringify({
    saturday: { date: satStr, weather: satWeather, plan: satPlan, holidays: holidays.filter(h => h.date === satStr) },
    sunday: { date: sunStr, weather: sunWeather, plan: sunPlan, holidays: holidays.filter(h => h.date === sunStr) },
    city: { id: cityId, name: city.name },
    timestamp: new Date().toISOString()
  });

  const response = new Response(body, {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
      'Cache-Control': 'public, max-age=1800'
    }
  });

  try { if (cache && cacheKey) await cache.put(cacheKey, response.clone()); } catch {}
  return response;
}
