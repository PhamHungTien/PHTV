<footer>
    <div class="container">
        <div class="footer-grid">
            <div class="footer-col">
                <div class="footer-brand">
                    <a href="<?php echo url(); ?>" class="logo">
                        <img src="<?php echo url('Resources/icon.png'); ?>" alt="Logo"> <?php echo esc_html(APP_NAME); ?>
                    </a>
                    <p class="footer-tagline"><?php echo esc_html(APP_FULL_NAME); ?></p>
                    <p>Bộ gõ tiếng Việt hiện đại, mã nguồn mở cho macOS.</p>
                </div>
            </div>
            <div class="footer-nav">
                <div class="footer-col">
                    <h4 data-i18n="footer.product">Sản Phẩm</h4>
                    <a href="#features">Tính năng</a>
                    <a href="<?php echo esc_url(DOWNLOAD_URL); ?>">Tải xuống</a>
                    <a href="<?php echo esc_url(GITHUB_URL); ?>">Mã nguồn</a>
                </div>
                <div class="footer-col">
                    <h4 data-i18n="footer.support">Hỗ Trợ</h4>
                    <a href="#setup">Cài đặt</a>
                    <a href="#faq">FAQ</a>
                    <a href="#feedback">Liên hệ</a>
                </div>
            </div>
        </div>

        <div class="footer-bottom">
            <div>&copy; 2025 <?php echo esc_html(META_AUTHOR); ?>. Licensed under GPLv3.</div>
            <div class="social-links">
                <a href="<?php echo esc_url(GITHUB_URL); ?>" target="_blank" aria-label="GitHub"><svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg></a>
                <a href="<?php echo esc_url(CONTACT_FACEBOOK); ?>" target="_blank" aria-label="Facebook"><svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor"><path d="M9.101 23.691v-7.98H6.627v-3.667h2.474v-1.58c0-4.085 1.848-5.978 5.858-5.978.401 0 .955.042 1.468.103a8.68 8.68 0 0 1 1.141.195v3.325a8.623 8.623 0 0 0-.653-.036c-2.148 0-2.797 1.603-2.797 2.87v1.101h4.188l-.582 3.667h-3.606v7.98H9.101z"/></svg></a>
                <a href="<?php echo esc_url(CONTACT_LINKEDIN); ?>" target="_blank" aria-label="LinkedIn"><svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg></a>
                <a href="mailto:<?php echo esc_attr(CONTACT_EMAIL); ?>" aria-label="Email"><span class="material-icons-round" style="font-size:20px">email</span></a>
            </div>
        </div>
    </div>
</footer>

<!-- Donate Modal -->
<div id="donateModal" class="modal">
    <div class="modal-content">
        <h3 style="margin-bottom: 20px;" data-i18n="donate.title">Cảm ơn bạn đã ủng hộ! ❤️</h3>
        <img src="<?php echo url('Resources/donate.png'); ?>" alt="Donate QR" style="width: 100%; border-radius: 12px; margin-bottom: 20px;">
        <p style="color: var(--text-sub); margin-bottom: 20px;" data-i18n="donate.desc">Sự đóng góp của bạn giúp duy trì và phát triển dự án.</p>
        <button class="btn btn-secondary" onclick="closeDonate()" style="width: 100%;" data-i18n="donate.close">Đóng</button>
    </div>
</div>

<!-- Gallery Lightbox -->
<div id="galleryLightbox" class="lightbox" onclick="closeLightbox()">
    <img id="lightboxImg" src="" alt="">
</div>

<!-- Scroll to Top Button -->
<button class="scroll-top" id="scrollTop" onclick="scrollToTop()" aria-label="Scroll to top">
    <span class="material-icons-round">keyboard_arrow_up</span>
</button>
