/**
 * Transport — Swiss Transport API integration.
 */

export const VERSION = '2.1.0';

export async function fetchTransportDisruptions(stationName) {
  try {
    const url = `https://transport.opendata.ch/v1/stationboard?station=${encodeURIComponent(stationName)}&limit=20`;
    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!res.ok) return { delays: [], summary: null };

    const data = await res.json();
    const delays = [];
    let maxDelay = 0, delayedCount = 0;

    for (const dep of data.stationboard || []) {
      const delay = dep.stop?.delay || 0;
      if (delay > 3) {
        delayedCount++;
        if (delay > maxDelay) maxDelay = delay;
        delays.push({
          line: `${dep.category || ''} ${dep.number || ''}`.trim(),
          destination: dep.to,
          delay,
          scheduledTime: dep.stop?.departure?.substring(11, 16) || '',
          platform: dep.stop?.platform || ''
        });
      }
    }

    delays.sort((a, b) => b.delay - a.delay);

    return {
      delays: delays.slice(0, 5),
      summary: delayedCount > 0
        ? { totalDelayed: delayedCount, maxDelay, status: maxDelay >= 15 ? 'major' : maxDelay >= 5 ? 'minor' : 'normal' }
        : null
    };
  } catch (e) {
    console.error('Transport error:', e.message);
    return { delays: [], summary: null };
  }
}

/**
 * Fetch next connections from a station to coordinates.
 * Swiss Transport API supports coordinate-based destinations.
 */
export async function fetchRoute(fromStation, toLat, toLon) {
  try {
    const toParam = `${toLat},${toLon}`;
    const url = `https://transport.opendata.ch/v1/connections?from=${encodeURIComponent(fromStation)}&to=${encodeURIComponent(toParam)}&limit=3`;
    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!res.ok) return { connections: [], nearestStop: null };

    const data = await res.json();
    const connections = (data.connections || []).map(c => {
      const sections = c.sections || [];
      const products = sections
        .filter(s => s.journey)
        .map(s => `${s.journey.category || ''} ${s.journey.number || ''}`.trim())
        .filter(Boolean);

      const lastSection = sections[sections.length - 1];
      const walkMin = (lastSection && !lastSection.journey)
        ? Math.round(((new Date(lastSection.arrival?.arrival) - new Date(lastSection.departure?.departure)) / 60000) || 0)
        : 0;

      const transfers = Math.max(0, sections.filter(s => s.journey).length - 1);
      const dep = c.from?.departure?.substring(11, 16) || '';
      const arr = c.to?.arrival?.substring(11, 16) || '';
      const durMatch = (c.duration || '').match(/(\d+)d(\d+):(\d+):(\d+)/);
      let duration = c.duration || '';
      if (durMatch) {
        const days = parseInt(durMatch[1]), hours = parseInt(durMatch[2]), mins = parseInt(durMatch[3]);
        const totalMin = days * 1440 + hours * 60 + mins;
        duration = totalMin >= 60 ? `${Math.floor(totalMin / 60)}h ${totalMin % 60}min` : `${totalMin} min`;
      }

      return { departure: dep, arrival: arr, duration, transfers, products, walkTime: walkMin > 0 ? `${walkMin} min` : null };
    });

    const nearestStop = data.to?.name || null;
    return { connections, nearestStop };
  } catch (e) {
    console.error('Route error:', e.message);
    return { connections: [], nearestStop: null };
  }
}

/**
 * Handle /route endpoint.
 */
export async function handleRoute(url, env) {
  const { getCity } = await import('./data.js');
  const cityId = url.searchParams.get('city') || 'zurich';
  const toLat = parseFloat(url.searchParams.get('toLat'));
  const toLon = parseFloat(url.searchParams.get('toLon'));

  if (isNaN(toLat) || isNaN(toLon)) {
    return new Response(JSON.stringify({ error: 'Missing toLat/toLon parameters' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' }
    });
  }

  const city = getCity(cityId);
  const result = await fetchRoute(city.station, toLat, toLon);

  return new Response(JSON.stringify({
    ...result,
    from: city.station,
    city: { id: cityId, name: city.name },
    sbbUrl: `https://www.sbb.ch/en/timetable.html?from=${encodeURIComponent(city.station)}&to=${toLat},${toLon}`,
    timestamp: new Date().toISOString()
  }), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
      'Cache-Control': 'public, max-age=60'
    }
  });
}
