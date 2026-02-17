/**
 * Lunch — Overpass API integration for nearby restaurants.
 */

export const VERSION = '2.0.0';

import { getCity } from './data.js';

const CUISINE_MAP = {
  swiss: 'swiss', schweizer: 'swiss', fondue: 'swiss', raclette: 'swiss',
  italian: 'italian', pizza: 'italian', pasta: 'italian',
  chinese: 'asian', japanese: 'asian', thai: 'asian', vietnamese: 'asian',
  indian: 'asian', korean: 'asian', sushi: 'asian', asian: 'asian', ramen: 'asian',
  kebab: 'kebab', turkish: 'kebab', döner: 'kebab', lebanese: 'kebab',
  middle_eastern: 'kebab', falafel: 'kebab',
  coffee_shop: 'cafe', coffee: 'cafe', cake: 'cafe', pastry: 'cafe',
  vegetarian: 'vegetarian', vegan: 'vegetarian',
  burger: 'fastfood', sandwich: 'fastfood',
  international: 'international', european: 'international',
  french: 'international', german: 'international', spanish: 'international',
  mexican: 'international', american: 'international'
};

function categorizeCuisine(tags) {
  if (tags.amenity === 'cafe') return 'cafe';
  if (tags['diet:vegetarian'] === 'only' || tags['diet:vegan'] === 'only') return 'vegetarian';
  const cuisine = (tags.cuisine || '').toLowerCase();
  for (const part of cuisine.split(/[;,_]/)) {
    if (CUISINE_MAP[part.trim()]) return CUISINE_MAP[part.trim()];
  }
  if (tags.amenity === 'fast_food') return 'fastfood';
  if (cuisine) return 'international';
  return 'other';
}

function parseTimeToMinutes(s) { const [h, m] = s.split(':').map(Number); return h * 60 + (m || 0); }

function dayAppliesToday(rule, today, todayNum) {
  const days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  const range = rule.match(/(Mo|Tu|We|Th|Fr|Sa|Su)\s*-\s*(Mo|Tu|We|Th|Fr|Sa|Su)/i);
  if (range) {
    const si = days.findIndex(d => d.toLowerCase() === range[1].toLowerCase());
    const ei = days.findIndex(d => d.toLowerCase() === range[2].toLowerCase());
    if (si !== -1 && ei !== -1) return si <= ei ? (todayNum >= si && todayNum <= ei) : (todayNum >= si || todayNum <= ei);
  }
  const mentions = rule.match(/\b(Mo|Tu|We|Th|Fr|Sa|Su)\b/gi);
  if (mentions) return mentions.some(d => d.toLowerCase() === today.toLowerCase());
  return !rule.match(/\b(Mo|Tu|We|Th|Fr|Sa|Su)\b/i);
}

function checkOpenForLunch(oh) {
  if (!oh) return null;
  if (oh.trim() === '24/7') return true;
  const now = new Date();
  const osmDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  const today = osmDays[now.getDay()];
  const todayNum = now.getDay() === 0 ? 6 : now.getDay() - 1;
  const rules = oh.split(';').map(r => r.trim()).filter(Boolean);
  let found = false, open = false;

  for (const rule of rules) {
    const lr = rule.toLowerCase();
    if (lr.includes('off') || lr.includes('closed')) { if (dayAppliesToday(rule, today, todayNum)) return false; continue; }
    if (!dayAppliesToday(rule, today, todayNum)) continue;
    found = true;
    const ranges = rule.match(/\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}/g);
    if (!ranges) continue;
    for (const r of ranges) {
      const [s, e] = r.split('-').map(x => parseTimeToMinutes(x.trim()));
      const end = e <= s ? e + 1440 : e;
      if (s < 840 && end > 660) open = true;
    }
  }
  if (!found) {
    for (const rule of rules) {
      if (rule.match(/^[\d:;\-\s,]+$/)) {
        const ranges = rule.match(/\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}/g);
        if (ranges) { found = true; for (const r of ranges) { const [s, e] = r.split('-').map(x => parseTimeToMinutes(x.trim())); const end = e <= s ? e + 1440 : e; if (s < 840 && end > 660) open = true; } }
      }
    }
  }
  return found ? open : null;
}

async function fetchOverpass(lat, lon) {
  const q = `[out:json][timeout:25];(node["amenity"="restaurant"](around:3000,${lat},${lon});node["amenity"="cafe"](around:3000,${lat},${lon});node["amenity"="fast_food"](around:3000,${lat},${lon}););out body;`;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 15000);
  try {
    const res = await fetch('https://overpass-api.de/api/interpreter', {
      method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `data=${encodeURIComponent(q)}`, signal: ctrl.signal
    });
    if (!res.ok) throw new Error(`Overpass ${res.status}`);
    const data = await res.json();
    return data.elements || [];
  } finally { clearTimeout(timer); }
}

function normalize(elements) {
  return elements.filter(el => el.tags?.name).map(el => {
    const t = el.tags;
    return {
      id: `osm-${el.id}`, name: t.name, lat: el.lat, lon: el.lon,
      amenity: t.amenity, cuisine: t.cuisine || null,
      cuisineCategory: categorizeCuisine(t),
      phone: t.phone || t['contact:phone'] || null,
      website: t.website || t['contact:website'] || null,
      openingHours: t.opening_hours || null,
      openForLunch: checkOpenForLunch(t.opening_hours),
      wheelchair: t.wheelchair || null,
      outdoorSeating: t.outdoor_seating === 'yes',
      takeaway: t.takeaway === 'yes' || t.takeaway === 'only',
      vegetarian: t['diet:vegetarian'] || null,
      vegan: t['diet:vegan'] || null
    };
  });
}

export async function handleLunch(url, env) {
  const cityId = url.searchParams.get('city') || 'zurich';
  const city = getCity(cityId);

  const cache = caches.default;
  const cacheKey = new Request(`https://cache.local/lunch-${cityId}`, { method: 'GET' });

  let cached = await cache.match(cacheKey);
  if (cached) {
    const body = await cached.text();
    return new Response(body, {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*', 'Cache-Control': 'public, max-age=1800' }
    });
  }

  const elements = await fetchOverpass(city.lat, city.lon);
  const spots = normalize(elements);

  const body = JSON.stringify({
    spots, center: { lat: city.lat, lon: city.lon },
    city: { id: cityId, name: city.name },
    timestamp: new Date().toISOString()
  });

  const response = new Response(body, {
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*', 'Cache-Control': 'public, max-age=1800' }
  });
  await cache.put(cacheKey, new Response(body, { headers: { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=1800' } }));
  return response;
}
