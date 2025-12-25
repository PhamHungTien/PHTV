<!DOCTYPE html>
<html lang="vi" data-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
    <meta name="theme-color" content="#09090b" media="(prefers-color-scheme: dark)">
    <meta name="theme-color" content="#fafafa" media="(prefers-color-scheme: light)">
    <meta name="color-scheme" content="dark light">

    <!-- Primary Meta Tags -->
    <title><?php echo esc_html(META_TITLE); ?></title>
    <meta name="title" content="<?php echo esc_attr(META_TITLE); ?>">
    <meta name="description" content="<?php echo esc_attr(META_DESCRIPTION); ?>">
    <meta name="keywords" content="<?php echo esc_attr(META_KEYWORDS); ?>">
    <meta name="author" content="<?php echo esc_attr(META_AUTHOR); ?>">
    <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1">
    <link rel="canonical" href="<?php echo esc_url(BASE_URL); ?>">

    <!-- Open Graph / Facebook -->
    <meta property="og:type" content="website">
    <meta property="og:url" content="<?php echo esc_url(BASE_URL); ?>">
    <meta property="og:title" content="<?php echo esc_attr(APP_FULL_NAME); ?> - Bộ Gõ cho macOS">
    <meta property="og:description" content="<?php echo esc_attr(META_DESCRIPTION); ?>">
    <meta property="og:image" content="<?php echo esc_url(OG_IMAGE); ?>">
    <meta property="og:image:width" content="<?php echo esc_attr(OG_IMAGE_WIDTH); ?>">
    <meta property="og:image:height" content="<?php echo esc_attr(OG_IMAGE_HEIGHT); ?>">
    <meta property="og:locale" content="vi_VN">
    <meta property="og:site_name" content="<?php echo esc_attr(APP_NAME); ?>">

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:url" content="<?php echo esc_url(BASE_URL); ?>">
    <meta name="twitter:title" content="<?php echo esc_attr(APP_FULL_NAME); ?>">
    <meta name="twitter:description" content="<?php echo esc_attr(META_DESCRIPTION); ?>">
    <meta name="twitter:image" content="<?php echo esc_url(OG_IMAGE); ?>">

    <!-- Favicons -->
    <link rel="icon" type="image/png" sizes="32x32" href="<?php echo url('Resources/icons/favicon-32x32.png'); ?>">
    <link rel="icon" type="image/png" sizes="16x16" href="<?php echo url('Resources/icons/favicon-16x16.png'); ?>">
    <link rel="icon" type="image/png" sizes="192x192" href="<?php echo url('Resources/icons/android-chrome-192x192.png'); ?>">
    <link rel="apple-touch-icon" sizes="180x180" href="<?php echo url('Resources/icons/apple-touch-icon.png'); ?>">
    <link rel="manifest" href="<?php echo url('manifest.json'); ?>">

    <!-- DNS Prefetch for faster external resource loading -->
    <link rel="dns-prefetch" href="//fonts.googleapis.com">
    <link rel="dns-prefetch" href="//fonts.gstatic.com">
    <link rel="dns-prefetch" href="//api.github.com">
    <link rel="dns-prefetch" href="//github.com">
    <link rel="dns-prefetch" href="//avatars.githubusercontent.com">

    <!-- Preconnect for critical third-party origins -->
    <link rel="preconnect" href="https://fonts.googleapis.com" crossorigin>
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="preconnect" href="https://api.github.com" crossorigin>

    <!-- Preload critical assets for faster rendering -->
    <link rel="preload" href="<?php echo asset('style.css'); ?>" as="style">
    <link rel="preload" href="<?php echo asset('script.js'); ?>" as="script">
    <link rel="preload" href="<?php echo url('Resources/icon.png'); ?>" as="image" type="image/png">
    <link rel="preload" href="<?php echo url('Resources/icons/favicon-32x32.png'); ?>" as="image" type="image/png">
    <link rel="preload" href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700;800&display=swap" as="style">
    <link rel="preload" href="https://fonts.googleapis.com/icon?family=Material+Icons+Round&display=swap" as="style">

    <!-- Prefetch for next likely navigation -->
    <link rel="prefetch" href="<?php echo esc_url(DOWNLOAD_URL); ?>">
    <link rel="prefetch" href="<?php echo url('privacy.html'); ?>">

    <!-- Stylesheets -->
    <link href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link href="https://fonts.googleapis.com/icon?family=Material+Icons+Round&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="<?php echo asset('style.css'); ?>">

    <?php partial('structured-data'); ?>
</head>
