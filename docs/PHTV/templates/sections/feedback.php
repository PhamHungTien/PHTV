<!-- Feedback Section -->
<section id="feedback" class="section">
    <div class="section-header reveal">
        <h2 class="section-title" data-i18n="feedback.title">Gửi Phản Hồi & Báo Lỗi</h2>
        <p class="section-desc" data-i18n="feedback.desc">Ý kiến của bạn giúp PHTV ngày càng hoàn thiện hơn.</p>
    </div>

    <div class="feedback-form reveal">
        <?php if ($message_status == 'success'): ?>
            <div style="background: rgba(16, 185, 129, 0.1); color: #10B981; padding: 12px; border-radius: 8px; margin-bottom: 20px; border: 1px solid rgba(16, 185, 129, 0.2);">
                <span class="material-icons-round" style="vertical-align: middle; margin-right: 5px;">check_circle</span> Gửi thành công!
            </div>
        <?php elseif ($message_status == 'error'): ?>
            <div style="background: rgba(239, 68, 68, 0.1); color: #EF4444; padding: 12px; border-radius: 8px; margin-bottom: 20px; border: 1px solid rgba(239, 68, 68, 0.2);">
                <span class="material-icons-round" style="vertical-align: middle; margin-right: 5px;">error</span> Có lỗi xảy ra.
            </div>
        <?php elseif ($message_status == 'error_csrf'): ?>
            <div style="background: rgba(239, 68, 68, 0.1); color: #EF4444; padding: 12px; border-radius: 8px; margin-bottom: 20px; border: 1px solid rgba(239, 68, 68, 0.2);">
                <span class="material-icons-round" style="vertical-align: middle; margin-right: 5px;">error</span> Lỗi bảo mật. Vui lòng tải lại trang.
            </div>
        <?php elseif ($message_status == 'error_spam'): ?>
            <div style="background: rgba(239, 68, 68, 0.1); color: #EF4444; padding: 12px; border-radius: 8px; margin-bottom: 20px; border: 1px solid rgba(239, 68, 68, 0.2);">
                <span class="material-icons-round" style="vertical-align: middle; margin-right: 5px;">error</span> Vui lòng đợi 30 giây trước khi gửi lại.
            </div>
        <?php elseif ($message_status == 'error_length'): ?>
            <div style="background: rgba(239, 68, 68, 0.1); color: #EF4444; padding: 12px; border-radius: 8px; margin-bottom: 20px; border: 1px solid rgba(239, 68, 68, 0.2);">
                <span class="material-icons-round" style="vertical-align: middle; margin-right: 5px;">error</span> Nội dung quá dài.
            </div>
        <?php elseif ($message_status == 'error_email'): ?>
            <div style="background: rgba(239, 68, 68, 0.1); color: #EF4444; padding: 12px; border-radius: 8px; margin-bottom: 20px; border: 1px solid rgba(239, 68, 68, 0.2);">
                <span class="material-icons-round" style="vertical-align: middle; margin-right: 5px;">error</span> Email không hợp lệ.
            </div>
        <?php endif; ?>

        <form method="POST" action="">
            <?php echo csrf_field(); ?>
            <div class="form-group">
                <label class="form-label" data-i18n="form.name">Họ và tên</label>
                <input type="text" name="name" class="form-input" required placeholder="Nhập tên của bạn...">
            </div>
            <div class="form-group">
                <label class="form-label" data-i18n="form.email">Email (Tùy chọn)</label>
                <input type="email" name="email" class="form-input" placeholder="email@example.com">
            </div>
            <div class="form-group">
                <label class="form-label" data-i18n="form.content">Nội dung</label>
                <textarea name="content" class="form-input" rows="5" required placeholder="Mô tả lỗi hoặc tính năng mong muốn..."></textarea>
            </div>
            <button type="submit" class="btn btn-primary" style="width: 100%;">
                <span data-i18n="form.submit">Gửi Phản Hồi</span>
            </button>
        </form>
    </div>
</section>
