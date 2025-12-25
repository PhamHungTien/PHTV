<nav class="navbar">
    <div class="container">
        <a href="<?php echo url(); ?>" class="logo">
            <img src="<?php echo url('Resources/icon.png'); ?>" alt="<?php echo esc_attr(APP_NAME); ?>">
            <span class="logo-name"><?php echo esc_html(APP_NAME); ?></span>
        </a>

        <ul class="nav-menu">
            <li><a href="#features" class="nav-link" data-i18n="nav.features">Tính năng</a></li>
            <li><a href="#comparison" class="nav-link" data-i18n="nav.comparison">So sánh</a></li>
            <li><a href="#setup" class="nav-link" data-i18n="nav.setup">Cài đặt</a></li>
            <li><a href="#faq" class="nav-link" data-i18n="nav.faq">Hỏi đáp</a></li>
        </ul>

        <div class="nav-actions">
            <button class="btn btn-icon" onclick="toggleTheme()" id="theme-btn" title="Giao diện">
                <span class="material-icons-round">light_mode</span>
            </button>
            <button class="btn btn-secondary btn-sm" onclick="toggleLanguage()" id="lang-btn">EN</button>
            <a href="<?php echo esc_url(GITHUB_URL); ?>" target="_blank" class="btn btn-icon" title="GitHub">
                <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
            </a>
            <a href="<?php echo esc_url(DOWNLOAD_URL); ?>" id="downloadBtn" class="btn btn-primary" target="_blank" rel="noopener">
                <span class="material-icons-round">download</span> <span data-i18n="hero.download">Tải xuống</span>
            </a>
            <button class="mobile-toggle" onclick="toggleMenu()"><span class="material-icons-round" style="font-size: 28px;">menu</span></button>
        </div>
    </div>
</nav>

<div class="mobile-menu" id="mobileMenu">
    <a href="#features" onclick="toggleMenu()" data-i18n="nav.features">Tính năng</a>
    <a href="#comparison" onclick="toggleMenu()" data-i18n="nav.comparison">So sánh</a>
    <a href="#setup" onclick="toggleMenu()" data-i18n="nav.setup">Cài đặt</a>
    <a href="#faq" onclick="toggleMenu()" data-i18n="nav.faq">Hỏi đáp</a>
    <a href="#feedback" onclick="toggleMenu()" data-i18n="nav.contact">Liên hệ</a>
    <div style="display:flex; gap:16px;">
        <button class="btn btn-secondary" onclick="toggleTheme()" id="theme-btn-mobile">Giao diện</button>
        <button class="btn btn-secondary" onclick="toggleLanguage(); toggleMenu()" id="lang-btn-mobile">English</button>
    </div>
    <button class="btn btn-icon" onclick="toggleMenu()"><span class="material-icons-round" style="font-size: 32px;">close</span></button>
</div>
