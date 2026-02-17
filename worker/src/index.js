/**
 * Today in Switzerland — Cloudflare Worker entry point.
 * Routes requests to the appropriate handler module.
 */

export const VERSION = '2.0.0';

import { handleNews, VERSION as NEWS_V } from './news.js';
import { handleActivities, VERSION as ACTIVITIES_V } from './activities.js';
import { handleWeekend, VERSION as WEEKEND_V } from './weekend.js';
import { handleLunch, VERSION as LUNCH_V } from './lunch.js';
import { handleSunshine, VERSION as SUNSHINE_V } from './sunshine.js';
import { VERSION as DATA_V } from './data.js';
import { VERSION as WEATHER_V } from './weather.js';
import { VERSION as TRANSPORT_V } from './transport.js';
import { VERSION as EVENTS_V } from './events.js';

function cors(env) {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Accept',
      'Access-Control-Max-Age': '86400'
    }
  });
}

function json(data, env) {
  return new Response(JSON.stringify(data), {
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' }
  });
}

function error(msg, status, env) {
  return new Response(JSON.stringify({ error: msg }), {
    status,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' }
  });
}

function handleVersion(url, env) {
  return json({
    worker: VERSION,
    modules: {
      index: VERSION,
      data: DATA_V,
      weather: WEATHER_V,
      transport: TRANSPORT_V,
      news: NEWS_V,
      activities: ACTIVITIES_V,
      events: EVENTS_V,
      weekend: WEEKEND_V,
      lunch: LUNCH_V,
      sunshine: SUNSHINE_V,
    },
    deployedAt: new Date().toISOString(),
  }, env);
}

const ROUTES = {
  '/': handleNews,
  '/activities': handleActivities,
  '/weekend': handleWeekend,
  '/lunch': handleLunch,
  '/sunshine': handleSunshine,
  '/version': handleVersion,
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return cors(env);

    const url = new URL(request.url);
    const handler = ROUTES[url.pathname];
    if (!handler) return error('Not found', 404, env);

    try {
      return await handler(url, env);
    } catch (e) {
      console.error(`[${url.pathname}] Error:`, e);
      return error(e.message || 'Internal error', 500, env);
    }
  }
};
