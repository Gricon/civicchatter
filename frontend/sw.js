// Service worker that unregisters itself
// This clears all caches and prevents future caching issues

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // Delete all caches
      const cacheNames = await caches.keys();
      await Promise.all(
        cacheNames.map(cacheName => caches.delete(cacheName))
      );
      
      // Unregister this service worker
      const registrations = await self.registration.unregister();
      console.log('Service worker unregistered and caches cleared');
      
      // Take control of all pages
      await clients.claim();
    })()
  );
});

// Don't intercept any fetch requests
self.addEventListener('fetch', () => {
  // Do nothing - let requests go through normally
});