const CACHE_PREFIX = 'forgewatch-static-';
const CACHE_NAME = `${CACHE_PREFIX}v1`;
const PRECACHE = [
  '/offline.html',
  '/manifest.webmanifest',
  '/css/style.css',
  '/css/login.css',
  '/js/app.js',
  '/js/auth.js',
  '/js/pwa.js',
  '/icons/forgewatch-192.png',
  '/icons/forgewatch-512.png',
  '/icons/forgewatch-maskable-192.png',
  '/icons/forgewatch-maskable-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE)));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
      .map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);

  // Never cache API, authentication, report, or other non-GET traffic.
  if (request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api/')) return;

  if (request.mode === 'navigate') {
    // HTML can contain authenticated state. Always ask Flask; use only a generic
    // offline document if the network is unavailable. Never store a page response.
    event.respondWith(fetch(request).catch(async () =>
      (await caches.match('/offline.html')) || new Response('Offline', { status: 503 })));
    return;
  }

  const isAppAsset = url.pathname.startsWith('/css/') || url.pathname.startsWith('/js/') ||
    url.pathname.startsWith('/icons/') || url.pathname === '/manifest.webmanifest' || url.pathname === '/offline.html';
  if (!isAppAsset) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    if (cached) return cached;
    const response = await fetch(request);
    if (response.ok && response.type === 'basic') await cache.put(request, response.clone());
    return response;
  })());
});
