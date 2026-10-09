// Deployed over flutter_service_worker.js, replacing whatever was there.
//
// Builds up to 9 October registered Flutter's generated service worker. That
// worker answers navigations from its own cache first, so a browser that has
// one keeps being handed the bundle it cached — the deploy succeeds, the files
// on the server change, and the visitor still sees the old app. Nothing the
// page does can undo that, because the worker decides whether the page is ever
// fetched; and clearing site data does not reliably unregister a worker that
// is controlling an open tab.
//
// A worker can only be replaced by a worker, so this is one: it claims every
// client, empties Cache Storage, unregisters itself and reloads the pages it
// was controlling. The browser re-checks the script URL it registered on
// navigation, finds these bytes instead of the old ones, and the old worker is
// gone for good — without the visitor doing anything.
//
// It stays deployed. Once it has run there is nothing left for it to do, and
// removing it would leave anyone who has not visited since still pinned.

self.addEventListener('install', (event) => {
  // Straight past "waiting": there is no reason to leave the old worker
  // serving one more navigation.
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    await self.clients.claim();

    const names = await caches.keys();
    await Promise.all(names.map((name) => caches.delete(name)));

    await self.registration.unregister();

    // The tab that is open right now was loaded from the old cache, so it is
    // still the old app on screen. Reload it: by now the worker is gone and
    // the request reaches the network.
    const clients = await self.clients.matchAll({ type: 'window' });
    for (const client of clients) {
      if ('navigate' in client) client.navigate(client.url);
    }
  })());
});

// Until the activate handler has finished, this worker is still in charge of
// the pages the old one was controlling. Pass everything to the network rather
// than to the stale cache, so even that window serves the current build.
self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});
