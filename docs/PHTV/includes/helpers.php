<?php
/**
 * Helper Functions
 * Utility functions used throughout the application
 *
 * @package PHTV
 * @version 2.0.0
 */

// Prevent direct access
if (!defined('PHTV_LOADED')) {
    exit('Direct access not permitted');
}

// ============================================
// CACHE BUSTING
// ============================================

/**
 * Get asset version for cache busting
 * Uses file modification time for automatic cache invalidation
 *
 * @param string $file Path to file relative to base
 * @return int|string File modification timestamp or APP_VERSION
 */
function get_asset_version($file) {
    $filepath = BASE_PATH . '/' . ltrim($file, '/');

    if (file_exists($filepath)) {
        return filemtime($filepath);
    }

    // Fallback to app version
    return defined('APP_VERSION') ? APP_VERSION : time();
}

/**
 * Generate versioned asset URL
 * Automatically appends version parameter for cache busting
 *
 * @param string $path Asset path
 * @return string Versioned asset URL
 */
function asset($path) {
    $version = get_asset_version($path);
    $url = url($path);

    // Add version parameter
    $separator = strpos($url, '?') !== false ? '&' : '?';
    return $url . $separator . 'v=' . $version;
}

// ============================================
// TEMPLATE RENDERING
// ============================================

/**
 * Include a template file
 * Provides variable scope isolation
 *
 * @param string $template Template name (without .php)
 * @param array $data Variables to extract into template scope
 * @param bool $return Whether to return output instead of echo
 * @return string|void
 */
function template($template, $data = [], $return = false) {
    $template_path = TEMPLATES_DIR . '/' . $template . '.php';

    if (!file_exists($template_path)) {
        if (is_debug()) {
            trigger_error("Template not found: $template", E_USER_WARNING);
        }
        return $return ? '' : null;
    }

    // Extract data into local scope
    extract($data);

    if ($return) {
        ob_start();
        include $template_path;
        return ob_get_clean();
    } else {
        include $template_path;
    }
}

/**
 * Include a partial template
 * Convenience function for including partials
 *
 * @param string $partial Partial name
 * @param array $data Data to pass to partial
 */
function partial($partial, $data = []) {
    template('partials/' . $partial, $data);
}

/**
 * Include a section template
 * Convenience function for including sections
 *
 * @param string $section Section name
 * @param array $data Data to pass to section
 */
function section($section, $data = []) {
    template('sections/' . $section, $data);
}

// ============================================
// DATA FORMATTING
// ============================================

/**
 * Format number with thousands separator
 *
 * @param int|float $number
 * @param int $decimals
 * @return string
 */
function number_format_short($number, $decimals = 0) {
    if ($number >= 1000000) {
        return number_format($number / 1000000, $decimals) . 'M';
    } else if ($number >= 1000) {
        return number_format($number / 1000, $decimals) . 'K';
    }
    return number_format($number, $decimals);
}

/**
 * Format file size
 *
 * @param int $bytes
 * @param int $decimals
 * @return string
 */
function format_file_size($bytes, $decimals = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];

    for ($i = 0; $bytes > 1024; $i++) {
        $bytes /= 1024;
    }

    return round($bytes, $decimals) . ' ' . $units[$i];
}

/**
 * Truncate string with ellipsis
 *
 * @param string $string
 * @param int $length
 * @param string $append
 * @return string
 */
function str_limit($string, $length = 100, $append = '...') {
    if (mb_strlen($string) <= $length) {
        return $string;
    }

    return rtrim(mb_substr($string, 0, $length)) . $append;
}

// ============================================
// CONDITIONAL RENDERING
// ============================================

/**
 * Render content if condition is true
 *
 * @param bool $condition
 * @param string $content
 * @return string
 */
function when($condition, $content) {
    return $condition ? $content : '';
}

/**
 * Add class names conditionally
 *
 * @param array $classes Associative array of class => condition
 * @return string
 */
function class_names($classes) {
    $result = [];

    foreach ($classes as $class => $condition) {
        if (is_int($class)) {
            // Non-conditional class (value is class name)
            $result[] = $condition;
        } else if ($condition) {
            // Conditional class
            $result[] = $class;
        }
    }

    return implode(' ', $result);
}

// ============================================
// ARRAY HELPERS
// ============================================

/**
 * Get value from array with default
 *
 * @param array $array
 * @param string $key
 * @param mixed $default
 * @return mixed
 */
function array_get($array, $key, $default = null) {
    return isset($array[$key]) ? $array[$key] : $default;
}

/**
 * Check if array has key
 *
 * @param array $array
 * @param string $key
 * @return bool
 */
function array_has($array, $key) {
    return isset($array[$key]);
}

// ============================================
// REQUEST HELPERS
// ============================================

/**
 * Get value from $_GET with default
 *
 * @param string $key
 * @param mixed $default
 * @return mixed
 */
function get_query($key, $default = null) {
    return array_get($_GET, $key, $default);
}

/**
 * Get value from $_POST with default
 *
 * @param string $key
 * @param mixed $default
 * @return mixed
 */
function get_post($key, $default = null) {
    return array_get($_POST, $key, $default);
}

/**
 * Check if request is POST
 *
 * @return bool
 */
function is_post() {
    return $_SERVER['REQUEST_METHOD'] === 'POST';
}

/**
 * Check if request is GET
 *
 * @return bool
 */
function is_get() {
    return $_SERVER['REQUEST_METHOD'] === 'GET';
}

/**
 * Get client IP address
 *
 * @return string
 */
function get_client_ip() {
    if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
        return $_SERVER['HTTP_CLIENT_IP'];
    } else if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        return $_SERVER['HTTP_X_FORWARDED_FOR'];
    } else {
        return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    }
}

// ============================================
// JSON HELPERS
// ============================================

/**
 * Load JSON file
 *
 * @param string $file Path to JSON file
 * @param bool $assoc Return as associative array
 * @return mixed|null
 */
function load_json($file, $assoc = true) {
    if (!file_exists($file)) {
        return null;
    }

    $content = file_get_contents($file);
    return json_decode($content, $assoc);
}

/**
 * Save data to JSON file
 *
 * @param string $file Path to JSON file
 * @param mixed $data Data to save
 * @param int $flags JSON encode flags
 * @return bool
 */
function save_json($file, $data, $flags = JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) {
    $json = json_encode($data, $flags);

    if ($json === false) {
        return false;
    }

    return file_put_contents($file, $json, LOCK_EX) !== false;
}

// ============================================
// CACHE HELPERS
// ============================================

/**
 * Get cache file path
 *
 * @param string $key Cache key
 * @return string
 */
function cache_path($key) {
    return CACHE_DIR . '/' . $key . '.cache';
}

/**
 * Check if cache exists and is valid
 *
 * @param string $key Cache key
 * @param int $lifetime Lifetime in seconds
 * @return bool
 */
function cache_valid($key, $lifetime = 3600) {
    $path = cache_path($key);

    if (!file_exists($path)) {
        return false;
    }

    return (time() - filemtime($path)) < $lifetime;
}

/**
 * Get value from cache
 *
 * @param string $key Cache key
 * @param int $lifetime Lifetime in seconds
 * @return mixed|null
 */
function cache_get($key, $lifetime = 3600) {
    if (!cache_valid($key, $lifetime)) {
        return null;
    }

    return load_json(cache_path($key));
}

/**
 * Save value to cache
 *
 * @param string $key Cache key
 * @param mixed $value Value to cache
 * @return bool
 */
function cache_put($key, $value) {
    return save_json(cache_path($key), $value);
}

/**
 * Clear cache
 *
 * @param string|null $key Specific key or null for all
 * @return bool
 */
function cache_clear($key = null) {
    if ($key === null) {
        // Clear all cache files
        $files = glob(CACHE_DIR . '/*.cache');
        foreach ($files as $file) {
            @unlink($file);
        }
        return true;
    } else {
        // Clear specific cache
        $path = cache_path($key);
        if (file_exists($path)) {
            return @unlink($path);
        }
        return true;
    }
}

// ============================================
// TRANSLATION (for future i18n)
// ============================================

/**
 * Translate string (placeholder for future i18n)
 *
 * @param string $key Translation key
 * @param array $replacements Replacement values
 * @return string
 */
function __($key, $replacements = []) {
    // For now, just return the key
    // In the future, load from translation files
    $translation = $key;

    // Replace placeholders
    foreach ($replacements as $placeholder => $value) {
        $translation = str_replace(':' . $placeholder, $value, $translation);
    }

    return $translation;
}
