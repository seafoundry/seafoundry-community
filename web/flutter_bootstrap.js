{{flutter_js}}
{{flutter_build_config}}

// Custom bootstrap to fix slow service worker timeout in development
const serviceWorkerVersion = {{flutter_service_worker_version}};
let serviceWorkerSettings = {
    serviceWorkerVersion: serviceWorkerVersion,
};

// Disable service worker in local development to avoid "prepareServiceWorker" timeouts
// which cause a 4+ second delay on startup.
if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    console.warn('Service worker disabled in development mode to speed up load time.');
    serviceWorkerSettings = null;
}

_flutter.loader.load({
    serviceWorkerSettings: serviceWorkerSettings,
    onEntrypointLoaded: function (engineInitializer) {
        engineInitializer.initializeEngine().then(function (appRunner) {
            appRunner.runApp();
        });
    }
});
