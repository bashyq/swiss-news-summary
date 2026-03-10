/**
 * News — RSS parsing, Claude API categorization, news assembly.
 */

export const VERSION = '2.2.0';

import { NATIONAL_SOURCES, getCity, getUpcomingHolidays, getThisDayInHistory, getSchoolHolidays } from './data.js';
import { fetchWeather, fetchWeekendWeather, RAINY_CODES } from './weather.js';
import { fetchTransportDisruptions } from './transport.js';
import { getCuratedActivities } from './activities.js';
import { getCityEvents } from './events.js';

/* ── RSS helpers ── */

function decodeEntities(text) {
  return text
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'")
    .replace(/&ndash;/g, '–').replace(/&mdash;/g, '—')
    .replace(/&uuml;/g, 'ü').replace(/&Uuml;/g, 'Ü')
    .replace(/&auml;/g, 'ä').replace(/&Auml;/g, 'Ä')
    .replace(/&ouml;/g, 'ö').replace(/&Ouml;/g, 'Ö');
}

function stripHTML(html) {
  return html.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
}

function parseRSSItems(xml) {
  const items = [];
  // Match both RSS <item> and Atom <entry> elements
  const itemRe = /<(?:item|entry)>([\s\S]*?)<\/(?:item|entry)>/gi;
  const field = (tag, str) => {
    const m = new RegExp(`<${tag}[^>]*>(?:<!\\[CDATA\\[)?(.*?)(?:\\]\\]>)?<\\/${tag}>`, 'i').exec(str);
    return m ? m[1].trim() : '';
  };
  // Atom <link href="..."/> (self-closing)
  const atomLink = (str) => {
    const m = /<link[^>]*href="([^"]+)"[^>]*(?:rel="alternate")?/i.exec(str);
    return m ? m[1] : '';
  };

  let m;
  while ((m = itemRe.exec(xml)) !== null && items.length < 15) {
    const x = m[1];
    const title = field('title', x);
    if (!title) continue;
    const dateStr = field('pubDate', x) || field('dc:date', x) || field('published', x) || field('updated', x);
    let publishedAt = null;
    if (dateStr) { try { const d = new Date(dateStr); if (!isNaN(d)) publishedAt = d.toISOString(); } catch {} }
    const url = field('link', x) || atomLink(x);
    items.push({
      title: decodeEntities(title),
      url,
      description: stripHTML(decodeEntities(field('description', x) || field('summary', x) || field('content', x))).substring(0, 200),
      publishedAt
    });
  }
  return items;
}

async function fetchFeed(source) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const res = await fetch(source.url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        Accept: 'application/rss+xml, application/xml, text/xml, */*'
      },
      signal: controller.signal
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return parseRSSItems(await res.text());
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchAllFeeds(sources) {
  const results = await Promise.allSettled(
    sources.map(async s => ({ source: s.name, type: s.type || null, headlines: await fetchFeed(s) }))
  );
  const all = [];
  for (const r of results) {
    if (r.status === 'fulfilled' && r.value.headlines?.length > 0) all.push(r.value);
  }
  return all;
}

function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [arr[i], arr[j]] = [arr[j], arr[i]]; }
  return arr;
}

function splitHeadlinesByType(allHeadlines) {
  const sourceName = (s) => s.source.replace(/^(NZZ|Reddit r\/).*/, m => m.startsWith('NZZ') ? 'NZZ' : 'Reddit').replace(/ Zürich| Schweiz/g, '');
  const general = [], culture = [], events = [], local = [];
  for (const s of allHeadlines) {
    const type = s.type || 'general';
    const name = sourceName(s);
    for (const item of s.headlines.slice(0, 8)) {
      const entry = { source: name, ...item };
      if (type === 'culture') culture.push(entry);
      else if (type === 'events') events.push(entry);
      else if (type === 'police') local.push({ source: `${name} (Police)`, ...item });
      else if (type !== 'trends') general.push(entry);
    }
  }
  return { general: shuffle(general), culture: shuffle(culture), events: shuffle(events), local: shuffle(local) };
}

function formatHeadlinesForPrompt(generalHeadlines) {
  return '\n' + generalHeadlines.slice(0, 45).map(h => `- [${h.source}] ${h.title}${h.url ? ` [URL: ${h.url}]` : ''}`).join('\n');
}

function buildPreAssigned(items, maxItems) {
  return shuffle(items).slice(0, maxItems).map(h => ({
    headline: h.title,
    summary: h.description || h.title,
    detail: '',
    source: h.source,
    url: h.url || '',
    sentiment: 'neutral'
  }));
}

/* ── Claude API ── */

async function getCategorizedNews(headlinesText, lang, apiKey, cityName) {
  const isEN = lang !== 'de';
  const prompt = isEN
    ? `You are a JSON API. Respond with ONLY valid JSON.

CRITICAL: ALL output must be in ENGLISH. Translate ALL German headlines and summaries to English.

RULES:
1. Categorize by TOPIC, not source — a story about elections goes to "politics" even if it's the biggest story of the day
2. TRANSLATE EVERYTHING TO ENGLISH - no German words allowed
3. 5-8 items per category. Spread stories evenly — don't put everything in topStories.
4. Swiss news only
5. For each item, assess sentiment: "positive" (good news, progress), "negative" (accidents, crises), or "neutral" (informational)
6. Identify the single biggest story/trending topic across all headlines. Include the URL of the best-matching article for the trending topic.
7. For each item, provide "summary" (1 short sentence visible by default) AND "detail" (1 additional sentence with context, shown on tap)
8. De-duplicate: if multiple sources report the same story, keep the best version only

CATEGORIES — categorize by primary topic:
- topStories: Breaking or unusual news that doesn't fit other categories. NOT a catch-all.
- politics: Government, parliament, elections, referendums, voting, party politics, laws, diplomacy. Election news ALWAYS goes here.
- events: Sports results, concerts, exhibitions, festivals
- culture: Entertainment, celebrities, lifestyle, arts, food, travel
- local: ${cityName}-specific news, local infrastructure, city council

Headlines:
${headlinesText}

Respond with ONLY this JSON (ALL IN ENGLISH):
{"trending":{"topic":"short topic","topicDE":"German topic","headline":"dominant headline","url":"best matching article URL"},"topStories":[{"headline":"English headline","summary":"Short summary.","detail":"Extra context sentence.","source":"SourceName","url":"url","sentiment":"positive|neutral|negative"}],"politics":[],"events":[],"culture":[],"local":[]}`
    : `Du bist eine JSON API. Kategorisiere Schweizer Nachrichten und antworte NUR mit gültigem JSON.

REGELN:
1. Nach THEMA kategorisieren, nicht Quelle — Wahlnachrichten gehören immer zu "politics", auch wenn sie die größte Story sind
2. 5-8 Einträge pro Kategorie. Gleichmässig verteilen — nicht alles in topStories.
3. Nur Schweizer Nachrichten
4. Für jeden Eintrag die Stimmung bewerten: "positive" (gute Nachrichten), "negative" (Unfälle, Krisen), oder "neutral" (informativ)
5. Das größte/dominanteste Thema über alle Schlagzeilen identifizieren. Die URL des passendsten Artikels angeben.
6. Für jeden Eintrag "summary" (1 kurzer Satz) UND "detail" (1 zusätzlicher Satz mit Kontext) angeben
7. Duplikate entfernen: bei gleicher Story aus mehreren Quellen nur die beste Version behalten

KATEGORIEN — nach Hauptthema:
- topStories: Aktuelle oder ungewöhnliche Nachrichten. KEIN Sammelbecken.
- politics: Regierung, Wahlen, Abstimmungen, Parteipolitik, Gesetze, Diplomatie. Wahlnachrichten IMMER hierher.
- events: Sport, Konzerte, Ausstellungen, Festivals
- culture: Unterhaltung, Prominente, Lifestyle, Kunst, Essen, Reisen
- local: ${cityName}-spezifische Nachrichten, lokale Infrastruktur

Schlagzeilen:
${headlinesText}

Antworte NUR mit diesem JSON:
{"trending":{"topic":"Kurzes Thema","topicDE":"Kurzes Thema DE","headline":"Dominante Schlagzeile","url":"URL des passendsten Artikels"},"topStories":[{"headline":"...","summary":"Kurze Zusammenfassung.","detail":"Zusätzlicher Kontext.","source":"...","url":"...","sentiment":"positive|neutral|negative"}],"politics":[],"events":[],"culture":[],"local":[]}`;

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' },
    body: JSON.stringify({ model: 'claude-3-haiku-20240307', max_tokens: 4096, messages: [{ role: 'user', content: prompt }] })
  });
  if (!res.ok) { const e = await res.text(); throw new Error(`Claude API ${res.status}: ${e}`); }

  const data = await res.json();
  let text = data.content[0].text;

  // Extract JSON
  if (text.includes('```')) {
    const m = text.match(/```(?:json)?\s*([\s\S]*?)```/);
    text = m ? m[1].trim() : text.replace(/```json?\n?|```/g, '').trim();
  }
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (jsonMatch) text = jsonMatch[0];

  try { return JSON.parse(text); }
  catch { return recoverPartialJSON(text); }
}

function recoverPartialJSON(str) {
  const result = { topStories: [], politics: [], events: [], culture: [], local: [] };
  const trendingM = str.match(/"trending"\s*:\s*(\{[^}]*\})/);
  if (trendingM) try { result.trending = JSON.parse(trendingM[1]); } catch {}

  for (const cat of Object.keys(result)) {
    const m = new RegExp(`"${cat}"\\s*:\\s*\\[`).exec(str);
    if (!m) continue;
    let depth = 0, start = -1;
    for (let i = m.index + m[0].length; i < str.length; i++) {
      if (str[i] === '{') { if (depth === 0) start = i; depth++; }
      else if (str[i] === '}') { depth--; if (depth === 0 && start !== -1) { try { const o = JSON.parse(str.substring(start, i + 1)); if (o.headline && o.source) result[cat].push(o); } catch {} start = -1; } }
      else if (str[i] === ']' && depth === 0) break;
    }
  }
  return result;
}

/* ── Daily Pick — weather-aware activity recommendation ── */

const PICK_EMOJIS = { animals:'🦁', museum:'🏛️', playground:'🛝', outdoor:'🌳', nature:'🌿', 'indoor-play':'🎪', event:'📅', seasonal:'🎄', cafe:'☕' };

function buildDailyPick(activities, weather, lang) {
  if (!activities?.length) return null;
  const cands = activities.filter(a => a.category !== 'stayhome');
  if (!cands.length) return null;

  const hour = new Date().getHours();
  const timeOfDay = hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening';
  const isRainy = weather && RAINY_CODES.includes(weather.weatherCode);
  const isCold = weather && weather.temperature < 5;
  const isHot = weather && weather.temperature > 28;
  const weatherType = isRainy ? 'rainy' : isCold ? 'cold' : isHot ? 'hot' : 'nice';

  // Score activities
  const scored = cands.map(a => {
    let score = 0;
    if ((isRainy || isCold) && a.indoor) score += 3;
    if (!isRainy && !isCold && !a.indoor) score += 2;
    if (a.featured) score += 2;
    if (timeOfDay === 'evening' && a.duration && a.duration.includes('1')) score += 1;
    if (timeOfDay === 'morning' && !a.indoor) score += 1;
    score += Math.random(); // tiebreak
    return { activity: a, score };
  });
  scored.sort((a, b) => b.score - a.score);
  const pick = scored[0].activity;

  const reasons = {
    rainy_morning: { en: `Rainy morning? ${pick.name} is the perfect indoor escape.`, de: `Regnerischer Morgen? ${pick.nameDE || pick.name} ist das perfekte Indoor-Ziel.` },
    rainy_afternoon: { en: `Rainy afternoon — head to ${pick.name} and stay dry!`, de: `Regnerischer Nachmittag — ab zu ${pick.nameDE || pick.name}!` },
    rainy_evening: { en: `Rainy evening? Cosy up at ${pick.name}.`, de: `Regnerischer Abend? Gemütlich in ${pick.nameDE || pick.name}.` },
    cold_morning: { en: `Cold outside! Warm up at ${pick.name}.`, de: `Kalt draussen! Aufwärmen in ${pick.nameDE || pick.name}.` },
    cold_afternoon: { en: `Bundle up or stay warm at ${pick.name}.`, de: `Warm einpacken oder aufwärmen in ${pick.nameDE || pick.name}.` },
    cold_evening: { en: `Cold evening — ${pick.name} is a great indoor choice.`, de: `Kalter Abend — ${pick.nameDE || pick.name} ist eine tolle Indoor-Wahl.` },
    hot_morning: { en: `Hot day ahead! Cool off at ${pick.name}.`, de: `Heisser Tag! Abkühlen in ${pick.nameDE || pick.name}.` },
    hot_afternoon: { en: `Beat the heat at ${pick.name}.`, de: `Der Hitze entfliehen in ${pick.nameDE || pick.name}.` },
    hot_evening: { en: `Warm evening — enjoy ${pick.name}.`, de: `Warmer Abend — geniesse ${pick.nameDE || pick.name}.` },
    nice_morning: { en: `Beautiful morning — head to ${pick.name}!`, de: `Schöner Morgen — ab zu ${pick.nameDE || pick.name}!` },
    nice_afternoon: { en: `Perfect afternoon for ${pick.name}.`, de: `Perfekter Nachmittag für ${pick.nameDE || pick.name}.` },
    nice_evening: { en: `Lovely evening — why not ${pick.name}?`, de: `Schöner Abend — wie wäre es mit ${pick.nameDE || pick.name}?` },
  };
  const key = `${weatherType}_${timeOfDay}`;
  const r = reasons[key] || reasons[`nice_${timeOfDay}`];

  return {
    activityId: pick.id,
    name: pick.name,
    nameDE: pick.nameDE || pick.name,
    reason: r.en,
    reasonDE: r.de,
    emoji: PICK_EMOJIS[pick.category] || '📍',
    indoor: pick.indoor,
    category: pick.category
  };
}

/* ── Weekend Brief — Sat+Sun weather + events ── */

function buildWeekendBrief(weekendWeather, cityEvents, cityId) {
  if (!weekendWeather?.length) return null;
  // Don't show on Sunday (ambiguous "this weekend")
  const dow = new Date().getDay();
  if (dow === 0) return null;

  const today = new Date();
  // Find next Saturday and Sunday
  const daysUntilSat = (6 - today.getDay() + 7) % 7 || 7;
  const satDate = new Date(today);
  satDate.setDate(today.getDate() + daysUntilSat);
  const sunDate = new Date(satDate);
  sunDate.setDate(satDate.getDate() + 1);

  const satStr = satDate.toISOString().split('T')[0];
  const sunStr = sunDate.toISOString().split('T')[0];

  const satWeather = weekendWeather.find(d => d.date === satStr);
  const sunWeather = weekendWeather.find(d => d.date === sunStr);

  if (!satWeather && !sunWeather) return null;

  // Find weekend events
  const weekendEvents = (cityEvents || []).filter(e => {
    const start = e.startDate;
    const end = e.endDate || e.startDate;
    return start <= sunStr && end >= satStr;
  }).slice(0, 3);

  return {
    saturday: satWeather || null,
    sunday: sunWeather || null,
    events: weekendEvents,
    satDate: satStr,
    sunDate: sunStr
  };
}

/* ── Main handler ── */

export async function handleNews(url, env) {
  if (!env.CLAUDE_API_KEY) throw new Error('Service unavailable — API key not configured');

  const lang = url.searchParams.get('lang') || 'en';
  const cityId = url.searchParams.get('city') || 'zurich';
  const forceRefresh = url.searchParams.get('refresh') === 'true';
  const city = getCity(cityId);

  // Try CF cache
  let cache, cacheKey;
  try {
    cacheKey = new Request(`https://cache.local/news-${cityId}-${lang}`, { method: 'GET' });
    cache = caches.default;
    if (!forceRefresh) {
      const cached = await cache.match(cacheKey);
      if (cached) {
        const h = new Headers(cached.headers);
        h.set('Access-Control-Allow-Origin', env.ALLOWED_ORIGIN || '*');
        h.set('X-Cache', 'HIT');
        return new Response(cached.body, { headers: h });
      }
    }
  } catch {}

  const allSources = [...NATIONAL_SOURCES, ...city.sources];
  const holidays = getUpcomingHolidays(cityId);
  const schoolHolidays = getSchoolHolidays();
  const historyFact = getThisDayInHistory();

  const [weather, transport, allHeadlines, weekendWeather] = await Promise.all([
    fetchWeather(city.lat, city.lon),
    fetchTransportDisruptions(city.station),
    fetchAllFeeds(allSources),
    fetchWeekendWeather(city.lat, city.lon)
  ]);

  if (allHeadlines.length === 0) throw new Error('Failed to fetch any news feeds');

  // Split headlines: general → Claude, culture/events/local → pre-assigned
  const split = splitHeadlinesByType(allHeadlines);
  let categories = await getCategorizedNews(formatHeadlinesForPrompt(split.general), lang, env.CLAUDE_API_KEY, city.name);

  // Retry with fewer headlines if empty
  const totalItems = Object.values(categories).flat().filter(i => i?.headline).length;
  if (totalItems === 0) {
    categories = await getCategorizedNews(formatHeadlinesForPrompt(split.general.slice(0, 20)), lang, env.CLAUDE_API_KEY, city.name);
  }

  // Merge pre-assigned culture/events/local items (from dedicated feeds)
  categories.culture = [...(categories.culture || []), ...buildPreAssigned(split.culture, 5)].slice(0, 8);
  categories.events = [...(categories.events || []), ...buildPreAssigned(split.events, 5)].slice(0, 8);
  categories.local = [...(categories.local || []), ...buildPreAssigned(split.local, 5)].slice(0, 8);

  // Build publishedAt map + normalize sentiment
  const pubMap = {};
  for (const s of allHeadlines) for (const i of s.headlines || []) if (i.url && i.publishedAt) pubMap[i.url] = i.publishedAt;
  const validSentiments = ['positive', 'neutral', 'negative'];
  for (const cat of ['topStories', 'politics', 'events', 'culture', 'local']) {
    for (const item of categories[cat] || []) {
      if (item.url && pubMap[item.url]) item.publishedAt = pubMap[item.url];
      if (!validSentiments.includes(item.sentiment)) item.sentiment = 'neutral';
    }
  }

  const trending = categories.trending || null;
  delete categories.trending;

  // Morning briefing + daily pick
  let briefing = null;
  try {
    let topStory = null;
    for (const cat of ['topStories', 'politics', 'events']) {
      if (categories[cat]?.length > 0) { topStory = { ...categories[cat][0], category: cat }; break; }
    }
    let dailyPick = null;
    try {
      const activities = await getCuratedActivities(env, cityId);
      dailyPick = buildDailyPick(activities, weather, lang);
    } catch {}
    if (topStory || dailyPick) briefing = { topStory, dailyPick };
  } catch {}

  // Weekend brief
  const cityEvents = getCityEvents(cityId);
  const weekendBrief = buildWeekendBrief(weekendWeather, cityEvents, cityId);

  const body = JSON.stringify({
    categories, weather, holidays, schoolHolidays, history: historyFact,
    transport, trending, briefing, weekendBrief,
    city: { id: cityId, name: city.name },
    timestamp: new Date().toISOString()
  });

  const response = new Response(body, {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
      'Cache-Control': 'public, max-age=1800',
      'X-Cache': 'MISS'
    }
  });

  // Cache 15 min
  try { if (cache && cacheKey) await cache.put(cacheKey, new Response(body, { headers: { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=1800' } })); } catch {}

  return response;
}
