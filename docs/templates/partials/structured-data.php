<!-- Schema.org Structured Data -->

<!-- SoftwareApplication Schema -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "<?php echo esc_js(APP_NAME); ?>",
    "alternateName": "<?php echo esc_js(APP_FULL_NAME); ?>",
    "description": "<?php echo esc_js(APP_DESCRIPTION); ?>",
    "applicationCategory": "UtilitiesApplication",
    "operatingSystem": "macOS <?php echo esc_js(MIN_MACOS_VERSION); ?>+",
    "offers": {
        "@type": "Offer",
        "price": "0",
        "priceCurrency": "USD"
    },
    "author": {
        "@type": "Person",
        "name": "<?php echo esc_js(META_AUTHOR); ?>",
        "url": "https://phamhungtien.com"
    },
    "downloadUrl": "<?php echo esc_js(DOWNLOAD_URL); ?>",
    "softwareVersion": "<?php echo esc_js(APP_VERSION); ?>",
    "aggregateRating": {
        "@type": "AggregateRating",
        "ratingValue": "5",
        "ratingCount": "100"
    },
    "screenshot": "<?php echo esc_js(url('Resources/UI/setting_bogo.png')); ?>",
    "featureList": "Telex, VNI, Simple Telex, Quick Telex shortcuts (cc→ch, gg→gi), Spell-checking, Macros, ESC Recovery, App-specific memory, Dark Mode, Swift 6.0, C++ Engine, Apple Silicon Native"
}
</script>

<!-- FAQPage Schema -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": [
        {
            "@type": "Question",
            "name": "PHTV là gì?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "PHTV viết tắt của Precision Hybrid Typing Vietnamese, là bộ gõ tiếng Việt mã nguồn mở tối ưu cho macOS, được xây dựng với Swift 6.0 và C++ engine."
            }
        },
        {
            "@type": "Question",
            "name": "PHTV có miễn phí không?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Có, PHTV hoàn toàn miễn phí và là phần mềm mã nguồn mở (GPLv3)."
            }
        },
        {
            "@type": "Question",
            "name": "Yêu cầu hệ thống của PHTV?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "macOS <?php echo esc_js(MIN_MACOS_VERSION); ?> (Sonoma) trở lên. Yêu cầu chip <?php echo esc_js(REQUIRED_ARCH); ?> - không hỗ trợ Intel Mac."
            }
        },
        {
            "@type": "Question",
            "name": "PHTV có thu thập dữ liệu không?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Không. PHTV hoạt động hoàn toàn offline, không kết nối internet và không gửi bất kỳ dữ liệu nào ra ngoài."
            }
        },
        {
            "@type": "Question",
            "name": "Quick Telex shortcuts là gì?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "Là tính năng gõ tắt thông minh: gõ cc tự động thành ch, gg thành gi, kk thành kh, qq thành qu, giúp gõ nhanh hơn và giảm lỗi chính tả."
            }
        },
        {
            "@type": "Question",
            "name": "PHTV hỗ trợ những ứng dụng nào?",
            "acceptedAnswer": {
                "@type": "Answer",
                "text": "PHTV hoạt động với mọi ứng dụng macOS và được tối ưu đặc biệt cho Spotlight, WhatsApp, Chrome, Edge, Claude Code CLI. Hỗ trợ nhớ bảng mã riêng cho từng ứng dụng."
            }
        }
    ]
}
</script>

<!-- WebSite Schema for Site Search Box -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "WebSite",
    "name": "<?php echo esc_js(APP_NAME); ?>",
    "alternateName": "<?php echo esc_js(APP_FULL_NAME); ?>",
    "url": "<?php echo esc_js(BASE_URL); ?>",
    "description": "<?php echo esc_js(APP_DESCRIPTION); ?>",
    "publisher": {
        "@type": "Organization",
        "name": "<?php echo esc_js(META_AUTHOR); ?>",
        "logo": {
            "@type": "ImageObject",
            "url": "<?php echo esc_js(OG_IMAGE); ?>"
        }
    },
    "potentialAction": {
        "@type": "SearchAction",
        "target": {
            "@type": "EntryPoint",
            "urlTemplate": "<?php echo esc_js(GITHUB_URL); ?>/search?q={search_term_string}"
        },
        "query-input": "required name=search_term_string"
    },
    "sameAs": [
        "<?php echo esc_js(GITHUB_URL); ?>",
        "<?php echo esc_js(CONTACT_GITHUB); ?>",
        "<?php echo esc_js(CONTACT_FACEBOOK); ?>",
        "<?php echo esc_js(CONTACT_LINKEDIN); ?>"
    ]
}
</script>

<!-- BreadcrumbList Schema -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
        {
            "@type": "ListItem",
            "position": 1,
            "name": "Home",
            "item": "https://phamhungtien.com/"
        },
        {
            "@type": "ListItem",
            "position": 2,
            "name": "<?php echo esc_js(APP_NAME); ?>",
            "item": "<?php echo esc_js(BASE_URL); ?>"
        }
    ]
}
</script>

<!-- Organization Schema -->
<script type="application/ld+json">
{
    "@context": "https://schema.org",
    "@type": "Organization",
    "name": "<?php echo esc_js(META_AUTHOR); ?>",
    "url": "https://phamhungtien.com",
    "logo": "<?php echo esc_js(OG_IMAGE); ?>",
    "description": "macOS Developer specializing in Swift and Vietnamese input methods",
    "sameAs": [
        "<?php echo esc_js(CONTACT_GITHUB); ?>",
        "<?php echo esc_js(CONTACT_FACEBOOK); ?>",
        "<?php echo esc_js(CONTACT_LINKEDIN); ?>"
    ],
    "contactPoint": {
        "@type": "ContactPoint",
        "email": "<?php echo esc_js(CONTACT_EMAIL); ?>",
        "contactType": "Developer Support"
    }
}
</script>
