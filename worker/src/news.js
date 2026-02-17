/**
 * News — RSS parsing, Claude API categorization, news assembly.
 */

export const VERSION = '2.0.0';

import { NATIONAL_SOURCES, getCity, getUpcomingHolidays, getThisDayInHistory } from './data.js';
import { fetchWeather, RAINY_CODES } from './weather.js';
import { fetchTransportDisruptions } from './transport.js';
import { getCuratedActivities } from './activities.js';

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
  const itemRe = /<item>([\s\S]*?)<\/item>/gi;
  const field = (tag, str) => {
    const m = new RegExp(`<${tag}>(?:<!\\[CDATA\\[)?(.*?)(?:\\]\\]>)?<\\/${tag}>`, 'i').exec(str);
    return m ? m[1].trim() : '';
  };

  let m;
  while ((m = itemRe.exec(xml)) !== null && items.length < 10) {
    const x = m[1];
    const title = field('title', x);
    if (!title) continue;
    const dateStr = field('pubDate', x) || field('dc:date', x);
    let publishedAt = null;
    if (dateStr) { try { const d = new Date(dateStr); if (!isNaN(d)) publishedAt = d.toISOString(); } catch {} }
    items.push({
      title: decodeEntities(title),
      url: field('link', x),
      description: stripHTML(decodeEntities(field('description', x))).substring(0, 200),
      publishedAt
    });
  }
  return items;
}

async function fetchFeed(source) {
  const res = await fetch(source.url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      Accept: 'application/rss+xml, application/xml, text/xml, */*'
    }
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return parseRSSItems(await res.text());
}

async function fetchAllFeeds(sources) {
  const all = [];
  for (let i = 0; i < sources.length; i += 4) {
    const batch = sources.slice(i, i + 4);
    const results = await Promise.allSettled(
      batch.map(async s => ({ source: s.name, headlines: await fetchFeed(s) }))
    );
    for (const r of results) {
      if (r.status === 'fulfilled' && r.value.headlines?.length > 0) all.push(r.value);
    }
  }
  return all;
}

function formatHeadlinesForPrompt(allHeadlines) {
  const flat = [];
  for (const s of allHeadlines) {
    for (const item of s.headlines) {
      flat.push({ source: s.source.replace(/^(NZZ|Reddit r\/).*/, m => m.startsWith('NZZ') ? 'NZZ' : 'Reddit').replace(/ Zürich| Schweiz/g, ''), ...item });
    }
  }
  // Shuffle
  for (let i = flat.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [flat[i], flat[j]] = [flat[j], flat[i]];
  }
  return '\n' + flat.slice(0, 40).map(h => `- [${h.source}] ${h.title}${h.url ? ` [URL: ${h.url}]` : ''}`).join('\n');
}

/* ── Claude API ── */

async function getCategorizedNews(headlinesText, lang, apiKey, cityName) {
  const isEN = lang !== 'de';
  const prompt = isEN
    ? `You are a JSON API. Respond with ONLY valid JSON.

CRITICAL: ALL output must be in ENGLISH. Translate ALL German headlines and summaries to English.

RULES:
1. Categorize by TOPIC, not source
2. TRANSLATE EVERYTHING TO ENGLISH - no German words allowed
3. 5-8 items per category
4. Swiss news only
5. For each item, assess sentiment: "positive" (good news, progress), "negative" (accidents, crises), or "neutral" (informational)
6. Identify the single biggest story/trending topic across all headlines. Include the URL of the best-matching article for the trending topic.
7. For each item, provide "summary" (1 short sentence) AND "detail" (2-3 sentences with more context and background)

CATEGORIES:
- topStories: The most important, impactful, or breaking news stories of the day — regardless of topic. Lead with the biggest headline.
- politics: Government, elections, laws, voting, diplomacy
- events: Concerts, exhibitions, festivals, sports
- culture: Entertainment, celebrities, reviews, lifestyle, arts
- local: ${cityName}-specific news

Headlines:
${headlinesText}

Respond with ONLY this JSON (ALL IN ENGLISH):
{"trending":{"topic":"short topic","topicDE":"German topic","headline":"dominant headline","url":"best matching article URL"},"topStories":[{"headline":"English headline here","summary":"One sentence summary","detail":"2-3 sentences with more context and background","source":"SourceName","url":"url","sentiment":"positive|neutral|negative"}],"politics":[],"events":[],"culture":[],"local":[]}`
    : `Du bist eine JSON API. Kategorisiere Schweizer Nachrichten und antworte NUR mit gültigem JSON.

REGELN:
1. Nach THEMA kategorisieren, nicht Quelle
2. 5-8 Einträge pro Kategorie
3. Nur Schweizer Nachrichten
4. Für jeden Eintrag die Stimmung bewerten: "positive" (gute Nachrichten), "negative" (Unfälle, Krisen), oder "neutral" (informativ)
5. Das größte/dominanteste Thema über alle Schlagzeilen identifizieren. Die URL des passendsten Artikels für das Trending-Thema angeben.
6. Für jeden Eintrag "summary" (1 kurzer Satz) UND "detail" (2-3 Sätze mit mehr Kontext und Hintergrund) angeben

KATEGORIEN:
- topStories: Die wichtigsten, bedeutendsten oder aktuellsten Nachrichten des Tages — themenübergreifend. Die größte Schlagzeile zuerst.
- politics: Regierung, Wahlen, Gesetze, Diplomatie
- events: Konzerte, Ausstellungen, Sport
- culture: Unterhaltung, Prominente, Lifestyle, Kunst
- local: ${cityName}-spezifische Nachrichten

Schlagzeilen:
${headlinesText}

Antworte NUR mit diesem JSON:
{"trending":{"topic":"Kurzes Thema","topicDE":"Kurzes Thema DE","headline":"Dominante Schlagzeile","url":"URL des passendsten Artikels"},"topStories":[{"headline":"...","summary":"Ein Satz Zusammenfassung","detail":"2-3 Sätze mit mehr Kontext und Hintergrund","source":"...","url":"...","sentiment":"positive|neutral|negative"}],"politics":[],"events":[],"culture":[],"local":[]}`;

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

/* ── Main handler ── */

export async function handleNews(url, env) {
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
  const historyFact = getThisDayInHistory();

  const [weather, transport, allHeadlines] = await Promise.all([
    fetchWeather(city.lat, city.lon),
    fetchTransportDisruptions(city.station),
    fetchAllFeeds(allSources)
  ]);

  if (allHeadlines.length === 0) throw new Error('Failed to fetch any news feeds');

  let categories = await getCategorizedNews(formatHeadlinesForPrompt(allHeadlines), lang, env.CLAUDE_API_KEY, city.name);

  // Retry with fewer headlines if empty
  const totalItems = Object.values(categories).flat().filter(i => i?.headline).length;
  if (totalItems === 0) {
    categories = await getCategorizedNews(formatHeadlinesForPrompt(allHeadlines.slice(0, 4)), lang, env.CLAUDE_API_KEY, city.name);
  }

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

  // Morning briefing
  let briefing = null;
  try {
    let topStory = null;
    for (const cat of ['topStories', 'politics', 'events']) {
      if (categories[cat]?.length > 0) { topStory = { ...categories[cat][0], category: cat }; break; }
    }
    let suggestedActivity = null;
    try {
      const activities = await getCuratedActivities(env, cityId);
      if (activities?.length) {
        let cands = activities.filter(a => a.category !== 'stayhome');
        if (weather) {
          const bad = RAINY_CODES.includes(weather.weatherCode) || weather.temperature < 5;
          if (bad) { const indoor = cands.filter(a => a.indoor); if (indoor.length) cands = indoor; }
        }
        suggestedActivity = cands[Math.floor(Math.random() * cands.length)];
      }
    } catch {}
    if (topStory || suggestedActivity) briefing = { topStory, suggestedActivity };
  } catch {}

  const body = JSON.stringify({
    categories, weather, holidays, history: historyFact,
    transport, trending, briefing,
    city: { id: cityId, name: city.name },
    timestamp: new Date().toISOString()
  });

  const response = new Response(body, {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
      'Cache-Control': 'public, max-age=900',
      'X-Cache': 'MISS'
    }
  });

  // Cache 15 min
  try { if (cache && cacheKey) await cache.put(cacheKey, new Response(body, { headers: { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=900' } })); } catch {}

  return response;
}
