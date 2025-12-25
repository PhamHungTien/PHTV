<!-- Gallery Section -->
<section id="gallery" class="section">
    <div class="section-header reveal">
        <h2 class="section-title" data-i18n="gallery.title">Giao Diện Ứng Dụng</h2>
        <p class="section-desc" data-i18n="gallery.desc">Khám phá giao diện hiện đại và trực quan của PHTV</p>
    </div>

    <div class="gallery-wrapper reveal">
        <div class="gallery-card" onclick="openLightbox(this.querySelector('img').src)">
            <img src="<?php echo url('Resources/UI/setting_bogo.png'); ?>" alt="Cài đặt kiểu gõ" loading="lazy">
            <div class="gallery-meta">
                <h4 data-i18n="gallery.img1">Kiểu gõ & Bảng mã</h4>
            </div>
        </div>
        <div class="gallery-card" onclick="openLightbox(this.querySelector('img').src)">
            <img src="<?php echo url('Resources/UI/setting_gotat.png'); ?>" alt="Gõ tắt" loading="lazy">
            <div class="gallery-meta">
                <h4 data-i18n="gallery.img3">Quản lý gõ tắt (Macro)</h4>
            </div>
        </div>
        <div class="gallery-card" onclick="openLightbox(this.querySelector('img').src)">
            <img src="<?php echo url('Resources/UI/setting_nangcao.png'); ?>" alt="Nâng cao" loading="lazy">
            <div class="gallery-meta">
                <h4 data-i18n="gallery.img4">Tùy chỉnh nâng cao</h4>
            </div>
        </div>
        <div class="gallery-card" onclick="openLightbox(this.querySelector('img').src)">
            <img src="<?php echo url('Resources/UI/setting_giaodien.png'); ?>" alt="Giao diện" loading="lazy">
            <div class="gallery-meta">
                <h4 data-i18n="gallery.img5">Tùy chỉnh giao diện</h4>
            </div>
        </div>
        <div class="gallery-card" onclick="openLightbox(this.querySelector('img').src)">
            <img src="<?php echo url('Resources/UI/setting_hethong.png'); ?>" alt="Hệ thống" loading="lazy">
            <div class="gallery-meta">
                <h4 data-i18n="gallery.img6">Cài đặt hệ thống</h4>
            </div>
        </div>
        <div class="gallery-card" onclick="openLightbox(this.querySelector('img').src)">
            <img src="<?php echo url('Resources/UI/setting_phimtat.png'); ?>" alt="Phím tắt" loading="lazy">
            <div class="gallery-meta">
                <h4 data-i18n="gallery.img7">Phím tắt tùy chỉnh</h4>
            </div>
        </div>
        <div class="gallery-card" onclick="openLightbox(this.querySelector('img').src)">
            <img src="<?php echo url('Resources/UI/menubar_bangma.png'); ?>" alt="Menu Bar Bảng mã" loading="lazy">
            <div class="gallery-meta">
                <h4 data-i18n="gallery.img2">Thanh menu - Kiểu gõ</h4>
            </div>
        </div>
        <div class="gallery-card" onclick="openLightbox(this.querySelector('img').src)">
            <img src="<?php echo url('Resources/UI/menubar_kieugo.png'); ?>" alt="Menu Bar Kiểu gõ" loading="lazy">
            <div class="gallery-meta">
                <h4 data-i18n="gallery.img8">Thanh menu - Bảng mã</h4>
            </div>
        </div>
    </div>
</section>
