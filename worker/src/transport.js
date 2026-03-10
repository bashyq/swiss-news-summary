/**
 * Transport — Swiss Transport API integration.
 */

export const VERSION = '2.1.0';

async function fetchStationboard(stationName) {
  const url = `https://transport.opendata.ch/v1/stationboard?station=${encodeURIComponent(stationName)}&limit=20`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  const res = await fetch(url, { headers: { Accept: 'application/json' }, signal: controller.signal });
  clearTimeout(timeout);
  if (!res.ok) return [];
  const data = await res.json();
  return data.stationboard || [];
}

export async function fetchTransportDisruptions(stationInput) {
  try {
    // Support single station string or array of stations
    const stations = Array.isArray(stationInput) ? stationInput : [stationInput];
    const boards = await Promise.allSettled(stations.map(s => fetchStationboard(s)));

    const delays = [];
    let maxDelay = 0, delayedCount = 0;
    const seen = new Set();

    for (const result of boards) {
      if (result.status !== 'fulfilled') continue;
      for (const dep of result.value) {
        const delay = dep.stop?.delay || 0;
        if (delay > 3) {
          // Dedupe by line+destination+time (same train may appear at multiple stations)
          const key = `${dep.category}${dep.number}-${dep.to}-${dep.stop?.departure?.substring(11, 16)}`;
          if (seen.has(key)) continue;
          seen.add(key);

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
