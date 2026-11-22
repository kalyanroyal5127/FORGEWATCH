(() => {
  if (!('serviceWorker' in navigator)) return;
  const supportedLocal = ['localhost', '127.0.0.1'].includes(location.hostname);
  if (location.protocol !== 'https:' && !supportedLocal) return;

  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker.js', { scope: '/' })
      .catch((error) => console.error('FORGEWATCH offline support could not start:', error));
  });
})();
