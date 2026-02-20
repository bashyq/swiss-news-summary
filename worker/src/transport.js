/**
 * Transport — Swiss Transport API integration.
 */

export const VERSION = '2.0.0';

export async function fetchTransportDisruptions(stationName) {
  try {
    const url = `https://transport.opendata.ch/v1/stationboard?station=${encodeURIComponent(stationName)}&limit=20`;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    const res = await fetch(url, { headers: { Accept: 'application/json' }, signal: controller.signal });
    clearTimeout(timeout);
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
