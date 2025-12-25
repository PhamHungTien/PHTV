<?php
/**
 * PHTV Website - Main Page
 * Landing page for PHTV Vietnamese Input Method
 *
 * @package PHTV
 * @version 2.0.0
 * @author Pham Hung Tien
 */

// ============================================
// BOOTSTRAP APPLICATION
// ============================================
require_once __DIR__ . '/bootstrap.php';

// ============================================
// FEEDBACK FORM HANDLER
// ============================================
$message_status = "";

if (FEATURE_FEEDBACK_FORM && is_post()) {
    // CSRF Protection
    if (!verify_csrf_token(get_post('csrf_token', ''))) {
        $message_status = "error_csrf";
    }
    // Rate Limiting
    else if (is_rate_limited('feedback')) {
        $message_status = "error_spam";
    }
    // Process Feedback
    else {
        $name = sanitize_string(get_post('name', 'Ẩn danh'));
        $email_input = trim(get_post('email', ''));
        $content = sanitize_string(get_post('content', ''));

        // Validate lengths
        if (!validate_length($name, 50) ||
            !validate_length($email_input, 100) ||
            !validate_length($content, 3000)) {
            $message_status = "error_length";
        }
        else {
            $email = sanitize_email($email_input);

            // Email validation
            if (!empty($email_input) && !$email) {
                $message_status = "error_email";
            }
            // Save feedback
            else if (!empty($content)) {
                $feedback_file = 'feedback_protected.php';

                // Create file if not exists
                if (!file_exists($feedback_file)) {
                    $initial_content = "<?php exit(); ?>\n" . json_encode([], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
                    @file_put_contents($feedback_file, $initial_content, LOCK_EX);
                }

                // Load existing feedback
                $current_data = [];
                if (file_exists($feedback_file)) {
                    $raw_content = file_get_contents($feedback_file);
                    $json_content = str_replace("<?php exit(); ?>\n", "", $raw_content);
                    $current_data = json_decode($json_content, true) ?? [];
                }

                // Add new entry
                $new_entry = [
                    'id' => uniqid(),
                    'time' => date('Y-m-d H:i:s'),
                    'ip' => get_client_ip(),
                    'name' => $name,
                    'email' => $email,
                    'content' => $content
                ];

                array_unshift($current_data, $new_entry);

                // Save feedback
                $json_string = json_encode($current_data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
                $secure_content = "<?php exit(); ?>\n" . $json_string;

                if (@file_put_contents($feedback_file, $secure_content, LOCK_EX)) {
                    $message_status = "success";
                    set_rate_limit('feedback');
                } else {
                    $message_status = "error";
                }
            }
        }
    }
}

// ============================================
// PAGE DATA
// ============================================
$page_data = [
    'message_status' => $message_status,
    'csrf_token' => get_csrf_token(),
    'app_version' => APP_VERSION,
    'download_url' => DOWNLOAD_URL,
    'github_url' => GITHUB_URL,
];

?>
<?php partial('head'); ?>
<body>

    <div class="mesh-bg"></div>

    <?php partial('navbar', $page_data); ?>

    <header class="hero container">
        <!-- Hero Branding -->
        <div class="hero-branding">
            <img class="hero-app-icon" src="<?php echo url('Resources/icon.png'); ?>" alt="<?php echo esc_attr(APP_NAME); ?> Icon">
            <div class="hero-title-words">
                <div class="word-line word-animate" style="--delay: 0.1s;"><span class="first-letter">P</span>recision</div>
                <div class="word-line word-animate" style="--delay: 0.2s;"><span class="first-letter">H</span>ybrid</div>
                <div class="word-line word-animate" style="--delay: 0.3s;"><span class="first-letter">T</span>yping</div>
                <div class="word-line word-animate" style="--delay: 0.4s;"><span class="first-letter">V</span>ietnamese</div>
            </div>
        </div>

        <p class="hero-desc" data-i18n="hero.desc">Bộ gõ mã nguồn mở được thiết kế dành riêng cho Apple Silicon. Loại bỏ độ trễ, giao diện chuẩn Native và bảo mật tuyệt đối.</p>

        <div class="hero-stats-wrapper">
            <div class="hero-stats">
                <div class="stat-item">
                    <strong>Native</strong>
                    <span class="stat-label">Apple Silicon</span>
                </div>
                <div class="stat-item">
                    <strong>100%</strong>
                    <span class="stat-label">Open Source</span>
                </div>
                <div class="stat-item">
                    <strong>100%</strong>
                    <span class="stat-label">Offline</span>
                </div>
            </div>
        </div>

        <div class="hero-buttons-wrapper">
            <div class="hero-buttons">
                <a href="<?php echo esc_url(DOWNLOAD_URL); ?>" id="downloadHeroBtn" class="btn btn-primary btn-lg" target="_blank" rel="noopener">
                    <span class="material-icons-round">apple</span> <span data-i18n="hero.download">Tải xuống cho macOS</span>
                </a>
                <button onclick="openDonate()" class="btn btn-secondary">
                    <span class="material-icons-round">favorite_border</span> <span data-i18n="hero.donate">Ủng hộ tác giả</span>
                </button>
            </div>
        </div>
    </header>

    <main class="container">
        <?php
        // Render all page sections using modular templates
        section('features', $page_data);
        section('comparison', $page_data);
        section('gallery', $page_data);
        section('setup', $page_data);
        section('faq', $page_data);
        section('feedback', $page_data);
        ?>
    </main>

    <?php partial('footer', $page_data); ?>

    <!-- Scripts -->
    <script src="<?php echo asset('script.js'); ?>"></script>

</body>
</html>
