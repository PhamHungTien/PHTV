// Service Worker for PHTV Website
// Version: 2.0.0
// Advanced caching strategy with versioning

const CACHE_VERSION = 'phtv-v2.0.0';
const CACHE_NAME = `${CACHE_VERSION}-${new Date().getTime()}`;

// Assets to cache immediately on install
const CRITICAL_CACHE = [
  '/PHTV/',
  '/PHTV/index.php',
  '/PHTV/style.css',
  '/PHTV/script.js',
  '/PHTV/manifest.json',
  '/PHTV/Resources/icon.png',
  '/PHTV/Resources/icons/favicon-32x32.png',
  '/PHTV/Resources/icons/favicon-16x16.png',
  '/PHTV/Resources/icons/apple-touch-icon.png',
  'https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700;800&display=swap',
  'https://fonts.googleapis.com/icon?family=Material+Icons+Round&display=swap'
];

// Assets to cache on first request
const RUNTIME_CACHE = [
  '/PHTV/Resources/UI/',
  '/PHTV/Resources/Setup/',
  '/PHTV/privacy.html',
  '/PHTV/404.html'
];

// Cache strategies
const CACHE_STRATEGIES = {
  // Cache first, fallback to network
  cacheFirst: ['image', 'font', 'style'],
  // Network first, fallback to cache
  networkFirst: ['document', 'script'],
  // Network only (no cache)
  networkOnly: ['api', 'analytics'],
  // Stale while revalidate
  staleWhileRevalidate: ['css', 'js']
};

// Install event - cache critical assets
self.addEventListener('install', (event) => {
  console.log('[SW] Installing Service Worker v' + CACHE_VERSION);

  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Caching critical assets');
        return cache.addAll(CRITICAL_CACHE.map(url => new Request(url, {cache: 'reload'})));
      })
      .then(() => {
        console.log('[SW] Critical assets cached successfully');
        return self.skipWaiting(); // Activate immediately
      })
      .catch((error) => {
        console.error('[SW] Cache installation failed:', error);
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating Service Worker v' + CACHE_VERSION);

  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((cacheName) => {
              // Delete old caches
              return cacheName.startsWith('phtv-') && cacheName !== CACHE_NAME;
            })
            .map((cacheName) => {
              console.log('[SW] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            })
        );
      })
      .then(() => {
        console.log('[SW] Service Worker activated');
        return self.clients.claim(); // Take control immediately
      })
  );
});

// Fetch event - serve from cache or network
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }

  // Skip external domains (except fonts)
  if (url.origin !== location.origin &&
      !url.hostname.includes('fonts.googleapis.com') &&
      !url.hostname.includes('fonts.gstatic.com')) {
    return;
  }

  // Skip API calls and analytics
  if (url.pathname.includes('/api/') ||
      url.pathname.includes('analytics') ||
      url.pathname.includes('feedback_protected.php')) {
    return;
  }

  event.respondWith(
    handleFetch(request)
  );
});

// Handle fetch with smart caching strategy
async function handleFetch(request) {
  const url = new URL(request.url);

  // Determine cache strategy based on resource type
  const resourceType = getResourceType(url);

  try {
    switch (resourceType) {
      case 'image':
      case 'font':
        return await cacheFirst(request);

      case 'document':
        return await networkFirst(request);

      case 'style':
      case 'script':
        return await staleWhileRevalidate(request);

      default:
        return await networkFirst(request);
    }
  } catch (error) {
    console.error('[SW] Fetch error:', error);

    // Fallback to offline page for documents
    if (resourceType === 'document') {
      const cache = await caches.open(CACHE_NAME);
      return await cache.match('/PHTV/404.html') || new Response('Offline', { status: 503 });
    }

    return new Response('Network error', { status: 503 });
  }
}

// Cache First strategy - good for static assets
async function cacheFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  if (cached) {
    return cached;
  }

  const response = await fetch(request);

  // Cache successful responses
  if (response && response.status === 200) {
    cache.put(request, response.clone());
  }

  return response;
}

// Network First strategy - good for dynamic content
async function networkFirst(request) {
  const cache = await caches.open(CACHE_NAME);

  try {
    const response = await fetch(request);

    // Cache successful responses
    if (response && response.status === 200) {
      cache.put(request, response.clone());
    }

    return response;
  } catch (error) {
    // Fallback to cache
    const cached = await cache.match(request);
    if (cached) {
      return cached;
    }
    throw error;
  }
}

// Stale While Revalidate - good for CSS/JS
async function staleWhileRevalidate(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  // Fetch fresh version in background
  const fetchPromise = fetch(request).then((response) => {
    if (response && response.status === 200) {
      cache.put(request, response.clone());
    }
    return response;
  });

  // Return cached version immediately, or wait for network
  return cached || fetchPromise;
}

// Determine resource type from URL
function getResourceType(url) {
  const pathname = url.pathname;
  const extension = pathname.split('.').pop().toLowerCase();

  // Images
  if (['jpg', 'jpeg', 'png', 'gif', 'svg', 'webp', 'ico'].includes(extension)) {
    return 'image';
  }

  // Fonts
  if (['woff', 'woff2', 'ttf', 'eot', 'otf'].includes(extension)) {
    return 'font';
  }

  // Styles
  if (extension === 'css' || pathname.includes('fonts.googleapis.com')) {
    return 'style';
  }

  // Scripts
  if (extension === 'js') {
    return 'script';
  }

  // Documents
  if (['html', 'php', ''].includes(extension) || pathname.endsWith('/')) {
    return 'document';
  }

  return 'other';
}

// Listen for messages from clients
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data && event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(CACHE_NAME).then((cache) => {
        return cache.addAll(event.data.urls);
      })
    );
  }
});

// Push notification support (for future updates)
self.addEventListener('push', (event) => {
  if (!event.data) return;

  const data = event.data.json();
  const options = {
    body: data.body || 'PHTV has a new update!',
    icon: '/PHTV/Resources/icon.png',
    badge: '/PHTV/Resources/icons/favicon-32x32.png',
    vibrate: [200, 100, 200],
    data: {
      url: data.url || '/PHTV/'
    }
  };

  event.waitUntil(
    self.registration.showNotification(data.title || 'PHTV Update', options)
  );
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    clients.openWindow(event.notification.data.url || '/PHTV/')
  );
});

console.log('[SW] Service Worker v' + CACHE_VERSION + ' loaded');
