<?php
/**
 * Security Configuration
 * Security headers and CSRF protection
 *
 * @package PHTV
 * @version 2.0.0
 */

// Prevent direct access
if (!defined('PHTV_LOADED')) {
    exit('Direct access not permitted');
}

// ============================================
// SECURITY HEADERS
// ============================================

/**
 * Set security headers for the response
 */
function set_security_headers() {
    // Remove server signature
    @header_remove('X-Powered-By');
    @header_remove('Server');

    // Prevent clickjacking
    header('X-Frame-Options: SAMEORIGIN');

    // XSS Protection
    header('X-XSS-Protection: 1; mode=block');

    // Prevent MIME type sniffing
    header('X-Content-Type-Options: nosniff');

    // Referrer Policy
    header('Referrer-Policy: strict-origin-when-cross-origin');

    // Permissions Policy
    header('Permissions-Policy: geolocation=(), microphone=(), camera=()');

    // Content Security Policy
    $csp = [
        "default-src 'self'",
        "script-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://www.googletagmanager.com https://cdn.simpleicons.org",
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
        "font-src 'self' https://fonts.gstatic.com data:",
        "img-src 'self' data: https: blob: https://avatars.githubusercontent.com",
        "connect-src 'self' https://fonts.googleapis.com https://fonts.gstatic.com https://api.github.com",
        "worker-src 'self'",
        "manifest-src 'self'",
        "frame-ancestors 'self'",
        "base-uri 'self'",
        "form-action 'self'"
    ];
    header('Content-Security-Policy: ' . implode('; ', $csp));
}

// ============================================
// SESSION SECURITY
// ============================================

/**
 * Initialize secure session
 */
function init_secure_session() {
    if (session_status() === PHP_SESSION_NONE) {
        // Session security settings
        ini_set('session.cookie_httponly', 1);
        ini_set('session.use_only_cookies', 1);
        ini_set('session.use_strict_mode', 1);

        // Enable secure cookies if HTTPS
        if (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') {
            ini_set('session.cookie_secure', 1);
        }

        // Set session name (don't use default PHPSESSID)
        session_name('PHTV_SESSION');

        // Start session
        session_start();

        // Regenerate session ID periodically
        if (!isset($_SESSION['created'])) {
            $_SESSION['created'] = time();
        } else if (time() - $_SESSION['created'] > 1800) { // 30 minutes
            session_regenerate_id(true);
            $_SESSION['created'] = time();
        }
    }
}

// ============================================
// CSRF PROTECTION
// ============================================

/**
 * Generate CSRF token
 * @return string
 */
function generate_csrf_token() {
    if (empty($_SESSION['csrf_token'])) {
        if (function_exists('random_bytes')) {
            $_SESSION['csrf_token'] = bin2hex(random_bytes(CSRF_TOKEN_LENGTH));
        } else {
            $_SESSION['csrf_token'] = bin2hex(openssl_random_pseudo_bytes(CSRF_TOKEN_LENGTH));
        }
    }
    return $_SESSION['csrf_token'];
}

/**
 * Get CSRF token
 * @return string
 */
function get_csrf_token() {
    return $_SESSION['csrf_token'] ?? generate_csrf_token();
}

/**
 * Verify CSRF token
 * @param string $token Token to verify
 * @return bool
 */
function verify_csrf_token($token) {
    return !empty($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
}

/**
 * Output CSRF token input field
 * @return string
 */
function csrf_field() {
    $token = get_csrf_token();
    return '<input type="hidden" name="csrf_token" value="' . htmlspecialchars($token) . '">';
}

// ============================================
// RATE LIMITING
// ============================================

/**
 * Check if user is rate limited
 * @param string $action Action identifier (e.g., 'form_submit')
 * @return bool True if rate limited
 */
function is_rate_limited($action = 'default') {
    $key = 'rate_limit_' . $action;

    if (isset($_SESSION[$key])) {
        $time_diff = time() - $_SESSION[$key];
        return $time_diff < RATE_LIMIT_SECONDS;
    }

    return false;
}

/**
 * Set rate limit timestamp
 * @param string $action Action identifier
 */
function set_rate_limit($action = 'default') {
    $_SESSION['rate_limit_' . $action] = time();
}

/**
 * Get time remaining until rate limit expires
 * @param string $action Action identifier
 * @return int Seconds remaining
 */
function get_rate_limit_remaining($action = 'default') {
    $key = 'rate_limit_' . $action;

    if (isset($_SESSION[$key])) {
        $time_diff = time() - $_SESSION[$key];
        $remaining = RATE_LIMIT_SECONDS - $time_diff;
        return max(0, $remaining);
    }

    return 0;
}

// ============================================
// INPUT SANITIZATION
// ============================================

/**
 * Sanitize string input
 * @param string $input
 * @return string
 */
function sanitize_string($input) {
    return htmlspecialchars(trim($input), ENT_QUOTES, 'UTF-8');
}

/**
 * Sanitize email input
 * @param string $email
 * @return string|false
 */
function sanitize_email($email) {
    $email = trim($email);
    return filter_var($email, FILTER_VALIDATE_EMAIL) ? $email : false;
}

/**
 * Validate input length
 * @param string $input
 * @param int $max_length
 * @return bool
 */
function validate_length($input, $max_length) {
    return strlen($input) <= $max_length;
}

// ============================================
// XSS PREVENTION
// ============================================

/**
 * Escape output for HTML
 * @param string $string
 * @return string
 */
function esc_html($string) {
    return htmlspecialchars($string, ENT_QUOTES, 'UTF-8');
}

/**
 * Escape output for HTML attributes
 * @param string $string
 * @return string
 */
function esc_attr($string) {
    return htmlspecialchars($string, ENT_QUOTES, 'UTF-8');
}

/**
 * Escape output for JavaScript
 * @param string $string
 * @return string
 */
function esc_js($string) {
    return json_encode($string, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT);
}

/**
 * Escape URL
 * @param string $url
 * @return string
 */
function esc_url($url) {
    return htmlspecialchars($url, ENT_QUOTES, 'UTF-8');
}
