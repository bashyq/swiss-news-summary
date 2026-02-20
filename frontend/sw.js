const CACHE_NAME = 'today-switzerland-v37';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/styles.css',
  '/app.js',
  '/widget.html',
  '/manifest.json',
  '/icon.svg'
];

// Install - cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    })
  );
  self.skipWaiting();
});

// Activate - clean old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    })
  );
  self.clients.claim();
});

// Fetch handler with strategy per request type
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);

  // API requests: stale-while-revalidate (serve cached instantly, refresh in bg)
  if (url.hostname.includes('workers.dev')) {
    event.respondWith(staleWhileRevalidate(event.request));
    return;
  }

  // Google Fonts: cache-first (fonts rarely change)
  if (url.hostname.includes('fonts.googleapis.com') || url.hostname.includes('fonts.gstatic.com')) {
    event.respondWith(cacheFirst(event.request));
    return;
  }

  // Leaflet CDN: cache-first
  if (url.hostname.includes('unpkg.com') || url.hostname.includes('tile.openstreetmap.org')) {
    event.respondWith(cacheFirst(event.request));
    return;
  }

  // Static assets: cache-first, update in background
  event.respondWith(cacheFirstWithRefresh(event.request));
});

// Serve from cache instantly; if not cached, fetch from network and cache
async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    return new Response('', { status: 503 });
  }
}

// Serve from cache instantly; always fetch in background to update cache
async function cacheFirstWithRefresh(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  // Always update in background
  const fetchPromise = fetch(request).then((response) => {
    if (response.ok) cache.put(request, response.clone());
    return response;
  }).catch(() => null);

  // Return cached immediately, or wait for network
  return cached || (await fetchPromise) || new Response('', { status: 503 });
}

// Serve cached API response instantly, fetch fresh in background
async function staleWhileRevalidate(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  const fetchPromise = fetch(request).then((response) => {
    if (response.ok) cache.put(request, response.clone());
    return response;
  }).catch(() => null);

  // If we have cached data, return it immediately (background fetch still runs)
  if (cached) return cached;

  // No cache — must wait for network
  const response = await fetchPromise;
  if (response) return response;

  // Fully offline, no cache
  return new Response(JSON.stringify({
    error: 'Offline',
    categories: { topStories: [], politics: [], events: [], culture: [], local: [] }
  }), {
    headers: { 'Content-Type': 'application/json' }
  });
}

// Push notification handler
self.addEventListener('push', (event) => {
  let data = { title: 'Today in Switzerland', body: 'Your daily briefing is ready!' };

  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data.body = event.data.text();
    }
  }

  const options = {
    body: data.body,
    icon: '/icon.svg',
    badge: '/icon.svg',
    tag: 'daily-briefing',
    renotify: true,
    data: {
      url: data.url || '/'
    },
    actions: [
      { action: 'open', title: 'Read Now' },
      { action: 'dismiss', title: 'Dismiss' }
    ]
  };

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  if (event.action === 'dismiss') return;

  const url = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow(url);
    })
  );
});
