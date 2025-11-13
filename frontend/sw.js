const CACHE = "cc-v1";
const PRECACHE_URLS = [
	"/index.html",
	"/styles.css",
	"/app.js",
	"/manifest.webmanifest",
];

// Install: cache essential assets and activate immediately
self.addEventListener("install", (e) => {
	self.skipWaiting();
	e.waitUntil(
		caches.open(CACHE).then((cache) => cache.addAll(PRECACHE_URLS))
	);
});

// Activate: take control of clients and clean up old caches
self.addEventListener("activate", (e) => {
	clients.claim();
	e.waitUntil(
		caches.keys().then((keys) =>
			Promise.all(
				keys
					.filter((k) => k !== CACHE)
					.map((k) => caches.delete(k))
			)
		)
	);
});

// Fetch handler: network-first for critical app assets, cache-first for others
self.addEventListener("fetch", (e) => {
	const req = e.request;
	const url = new URL(req.url);

	// Only handle same-origin requests
	if (url.origin !== location.origin) return;

	// Network-first for core app files so users get updates after sign-in
	if (PRECACHE_URLS.includes(url.pathname) || url.pathname.endsWith("/")) {
		e.respondWith(
			fetch(req)
				.then((res) => {
					// Update cache in background
					const copy = res.clone();
					caches.open(CACHE).then((cache) => cache.put(req, copy));
					return res;
				})
				.catch(() => caches.match(req))
		);
		return;
	}

	// For other requests, try cache first then network
	e.respondWith(caches.match(req).then((res) => res || fetch(req)));
});
