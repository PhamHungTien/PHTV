<?php
/**
 * Application Configuration
 * PHTV Website - Core Settings
 *
 * @package PHTV
 * @version 2.0.0
 */

// Prevent direct access
if (!defined('PHTV_LOADED')) {
    exit('Direct access not permitted');
}

// ============================================
// APP INFORMATION
// ============================================
define('APP_NAME', 'PHTV');
define('APP_FULL_NAME', 'Precision Hybrid Typing Vietnamese');
define('APP_DESCRIPTION', 'Bộ gõ tiếng Việt mã nguồn mở cho macOS, được xây dựng riêng cho Apple Silicon với Swift 6.0 và C++ engine');

// Version (loaded from GitHub stats or fallback)
$githubStats = @json_decode(file_get_contents(__DIR__ . '/../cache/github_stats.json'), true);
define('APP_VERSION', $githubStats['version'] ?? 'v1.2.2');
define('APP_BUILD', date('YmdH')); // Build number

// ============================================
// PATHS & URLs
// ============================================
define('BASE_PATH', dirname(__DIR__)); // /path/to/PHTV
define('BASE_URL', 'https://phamhungtien.com/PHTV/');
define('GITHUB_URL', 'https://github.com/PhamHungTien/PHTV');
define('DOWNLOAD_URL', GITHUB_URL . '/releases/latest');

// ============================================
// DIRECTORIES
// ============================================
define('CONFIG_DIR', BASE_PATH . '/config');
define('INCLUDES_DIR', BASE_PATH . '/includes');
define('TEMPLATES_DIR', BASE_PATH . '/templates');
define('CACHE_DIR', BASE_PATH . '/cache');
define('RESOURCES_DIR', BASE_PATH . '/Resources');

// ============================================
// ENVIRONMENT
// ============================================
define('ENVIRONMENT', getenv('APP_ENV') ?: 'production'); // development | production
define('DEBUG_MODE', ENVIRONMENT === 'development');

// Error reporting
if (DEBUG_MODE) {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
} else {
    error_reporting(0);
    ini_set('display_errors', 0);
}

// ============================================
// TIMEZONE
// ============================================
date_default_timezone_set('Asia/Ho_Chi_Minh');

// ============================================
// CONTACT INFORMATION
// ============================================
define('CONTACT_EMAIL', 'phamhungtien@maclife.io');
define('CONTACT_FACEBOOK', 'https://www.facebook.com/phamhungtien1404');
define('CONTACT_LINKEDIN', 'https://www.linkedin.com/in/phamhungtien1404/');
define('CONTACT_GITHUB', 'https://github.com/PhamHungTien');

// ============================================
// SYSTEM REQUIREMENTS
// ============================================
define('MIN_MACOS_VERSION', '14.0');
define('REQUIRED_ARCH', 'Apple Silicon (M1/M2/M3/M4)');
define('TECH_STACK', 'Swift 6.0 + C++ Engine');

// ============================================
// FEATURE FLAGS
// ============================================
define('FEATURE_SERVICE_WORKER', true);
define('FEATURE_PWA', true);
define('FEATURE_ANALYTICS', false); // Set to true when GA is configured
define('FEATURE_FEEDBACK_FORM', true);

// ============================================
// CACHE SETTINGS
// ============================================
define('CACHE_ENABLED', true);
define('CACHE_CSS_LIFETIME', 31536000); // 1 year
define('CACHE_JS_LIFETIME', 31536000);  // 1 year
define('CACHE_IMAGE_LIFETIME', 2592000); // 1 month
define('CACHE_FONT_LIFETIME', 31536000); // 1 year

// ============================================
// SECURITY
// ============================================
define('CSRF_TOKEN_LENGTH', 32);
define('RATE_LIMIT_SECONDS', 30); // Minimum seconds between form submissions

// ============================================
// SEO METADATA
// ============================================
define('META_TITLE', 'PHTV - Bộ Gõ Tiếng Việt Tối Ưu cho macOS');
define('META_DESCRIPTION', 'Bộ gõ tiếng Việt mã nguồn mở cho Apple Silicon. Swift 6.0 + C++ engine. Quick Telex shortcuts, spell-checking, macros, app-specific memory. Offline, nhanh, bảo mật.');
define('META_KEYWORDS', 'PHTV, Precision Hybrid Typing Vietnamese, bộ gõ tiếng việt, vietnamese input method, macOS, unikey mac, vni, telex, gõ tiếng việt mac, apple silicon, m1, m2, m3, m4');
define('META_AUTHOR', 'Pham Hung Tien');

// ============================================
// SOCIAL MEDIA
// ============================================
define('OG_IMAGE', BASE_URL . 'Resources/icon.png');
define('OG_IMAGE_WIDTH', '1200');
define('OG_IMAGE_HEIGHT', '630');

// ============================================
// ANALYTICS (Optional)
// ============================================
// define('GA_MEASUREMENT_ID', 'G-XXXXXXXXXX'); // Uncomment and set when ready

// ============================================
// CUSTOM FUNCTIONS
// ============================================

/**
 * Check if a feature is enabled
 * @param string $feature Feature constant name
 * @return bool
 */
function is_feature_enabled($feature) {
    return defined($feature) && constant($feature) === true;
}

/**
 * Get full URL for a path
 * @param string $path Path relative to base
 * @return string
 */
function url($path = '') {
    return BASE_URL . ltrim($path, '/');
}

/**
 * Get full filesystem path
 * @param string $path Path relative to base
 * @return string
 */
function path($path = '') {
    return BASE_PATH . '/' . ltrim($path, '/');
}

/**
 * Check if we're in debug mode
 * @return bool
 */
function is_debug() {
    return DEBUG_MODE;
}

/**
 * Log debug message (only in debug mode)
 * @param mixed $message
 * @param string $level
 */
function debug_log($message, $level = 'INFO') {
    if (!is_debug()) return;

    $timestamp = date('Y-m-d H:i:s');
    $log_message = "[$timestamp] [$level] " . (is_array($message) ? print_r($message, true) : $message) . PHP_EOL;

    error_log($log_message, 3, CACHE_DIR . '/debug.log');
}
