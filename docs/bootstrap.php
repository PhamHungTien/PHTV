<?php
/**
 * Bootstrap File
 * Initializes the application and loads all dependencies
 *
 * @package PHTV
 * @version 2.0.0
 */

// ============================================
// SECURITY CHECK
// ============================================
define('PHTV_LOADED', true);

// ============================================
// OUTPUT BUFFERING
// ============================================
ob_start();

// ============================================
// LOAD CONFIGURATION
// ============================================
require_once __DIR__ . '/config/app.php';
require_once __DIR__ . '/config/security.php';

// ============================================
// LOAD HELPERS
// ============================================
require_once __DIR__ . '/includes/helpers.php';

// ============================================
// INITIALIZE CACHE HEADERS
// ============================================

/**
 * Set cache headers for current request
 */
function set_cache_headers() {
    // No cache for HTML/PHP - always serve fresh
    header('Cache-Control: no-cache, must-revalidate, max-age=0');
    header('Pragma: no-cache');
    header('Expires: 0');
}

// ============================================
// INITIALIZE SESSION
// ============================================
init_secure_session();

// ============================================
// SET SECURITY HEADERS
// ============================================
set_security_headers();

// ============================================
// SET CACHE HEADERS
// ============================================
set_cache_headers();

// ============================================
// ERROR HANDLING
// ============================================

/**
 * Custom error handler
 */
function phtv_error_handler($errno, $errstr, $errfile, $errline) {
    if (!(error_reporting() & $errno)) {
        return false;
    }

    $error_message = "Error [$errno]: $errstr in $errfile on line $errline";

    // Log error
    debug_log($error_message, 'ERROR');

    // Show error in debug mode only
    if (is_debug()) {
        echo "<div style='background:#fee; border:1px solid #f00; padding:10px; margin:10px;'>";
        echo "<strong>Error:</strong> $errstr<br>";
        echo "<strong>File:</strong> $errfile<br>";
        echo "<strong>Line:</strong> $errline";
        echo "</div>";
    }

    return true;
}

/**
 * Custom exception handler
 */
function phtv_exception_handler($exception) {
    $error_message = "Uncaught Exception: " . $exception->getMessage();
    debug_log($error_message, 'EXCEPTION');

    if (is_debug()) {
        echo "<div style='background:#fee; border:1px solid #f00; padding:10px; margin:10px;'>";
        echo "<strong>Exception:</strong> " . $exception->getMessage() . "<br>";
        echo "<strong>File:</strong> " . $exception->getFile() . "<br>";
        echo "<strong>Line:</strong> " . $exception->getLine() . "<br>";
        echo "<pre>" . $exception->getTraceAsString() . "</pre>";
        echo "</div>";
    } else {
        // Show generic error in production
        echo "An error occurred. Please try again later.";
    }
}

// Set custom handlers
if (!is_debug()) {
    set_error_handler('phtv_error_handler');
    set_exception_handler('phtv_exception_handler');
}

// ============================================
// STARTUP LOG
// ============================================
debug_log("Application started - Version: " . APP_VERSION . " - Environment: " . ENVIRONMENT);
