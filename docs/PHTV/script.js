// Language System
const translations = {
  vi: {
    'nav.features': 'Tính năng',
    'nav.setup': 'Cài đặt',
    'nav.faq': 'Hỏi đáp',
    'nav.contact': 'Liên hệ',
    'nav.comparison': 'So sánh',
    'hero.title':
      "Gõ Tiếng Việt <span class='text-gradient'>Tối Ưu</span> cho macOS",
    'hero.desc':
      'Bộ gõ mã nguồn mở được thiết kế dành riêng cho Apple Silicon. Loại bỏ độ trễ, giao diện chuẩn Native và bảo mật tuyệt đối.',
    'hero.open_source': 'Mã nguồn mở',
    'hero.download': 'Tải xuống cho macOS',
    'hero.donate': 'Ủng hộ tác giả',
    'features.title': 'Tại sao chọn PHTV?',
    'features.desc':
      'Được thiết kế để khắc phục các hạn chế của bộ gõ mặc định, mang lại trải nghiệm gõ phím mượt mà và ổn định nhất.',
    'feat1.title': 'Hiệu Năng Vượt Trội',
    'feat1.desc':
      'Viết bằng Swift thuần túy, không sử dụng framework nặng. Phản hồi tức thì, không gây lag khi gõ nhanh, đặc biệt tối ưu cho chip M1/M2/M3.',
    'feat2.title': 'Bảo Mật Tuyệt Đối',
    'feat2.desc':
      'Mã nguồn mở 100% trên GitHub. Không thu thập dữ liệu, offline 100%.',
    'feat3.title': 'Giao Diện Chuẩn macOS',
    'feat3.desc':
      'Hỗ trợ Dark Mode và giao diện trong suốt đẹp mắt.',
    'feat4.title': 'Tùy Biến Mạnh Mẽ',
    'feat4.desc':
      'Hỗ trợ đầy đủ Telex, VNI, Simple Telex. Cho phép định nghĩa phím tắt và macro thông minh, giúp tăng tốc độ soạn thảo văn bản đáng kể.',
    'feat5.title': 'Tương Thích Tuyệt Đối',
    'feat5.desc':
      'Hoạt động ổn định trên mọi ứng dụng: Microsoft Office, Adobe Creative Cloud, VS Code, Chrome, Safari và các IDE lập trình chuyên dụng. Khắc phục triệt để lỗi gạch chân khó chịu.',
    'gallery.title': 'Giao Diện Ứng Dụng',
    'gallery.desc': 'Khám phá giao diện hiện đại và trực quan của PHTV',
    'gallery.img1': 'Kiểu gõ & Bảng mã',
    'gallery.img2': 'Thanh menu - Kiểu gõ',
    'gallery.img3': 'Quản lý gõ tắt (Macro)',
    'gallery.img4': 'Tùy chỉnh nâng cao',
    'gallery.img5': 'Tùy chỉnh giao diện',
    'gallery.img6': 'Cài đặt hệ thống',
    'gallery.img7': 'Phím tắt tùy chỉnh',
    'gallery.img8': 'Thanh menu - Bảng mã',
    'setup.title': 'Hướng Dẫn Cài Đặt',
    'step1.title': 'Kéo vào Applications',
    'step1.desc':
      'Mở file DMG và kéo biểu tượng PHTV vào thư mục Applications để cài đặt.',
    'step2.title': 'Nhấn nút Mở',
    'step2.desc': 'Mở ứng dụng PHTV lần đầu tiên, nhấn nút "Mở" để xác nhận.',
    'step3.title': 'Chọn Cấp quyền',
    'step3.desc': 'Nhấn nút "Cấp quyền" để cho phép PHTV hoạt động.',
    'step4.title': 'Mở cài đặt Hệ thống',
    'step4.desc':
      'Chọn "Mở cài đặt Hệ thống" để đi đến phần cài đặt quyền truy cập.',
    'step5.title': 'Bật quyền Trợ năng',
    'step5.desc':
      'Bật quyền trợ năng cho PHTV trong cài đặt Hệ thống. Hoàn tất!',
    'faq.title': 'Câu Hỏi Thường Gặp',
    q1: 'PHTV có miễn phí không?',
    a1: 'Có, PHTV hoàn toàn miễn phí và là phần mềm mã nguồn mở (GPLv3).',
    q2: 'Yêu cầu hệ thống?',
    a2: 'macOS 14.0 (Sonoma) trở lên. Tối ưu nhất cho chip Apple Silicon (M1/M2/M3/M4).',
    q3: 'PHTV có thu thập dữ liệu không?',
    a3: 'Không. PHTV hoạt động hoàn toàn offline, không kết nối internet và không gửi bất kỳ dữ liệu nào ra ngoài.',
    'feedback.title': 'Gửi Phản Hồi & Báo Lỗi',
    'feedback.desc': 'Ý kiến của bạn giúp PHTV ngày càng hoàn thiện hơn.',
    'feedback.github_title': 'Báo lỗi qua GitHub Issues',
    'feedback.github_desc': 'Tạo issue trên GitHub để báo lỗi hoặc đề xuất tính năng mới. Chúng tôi sẽ phản hồi nhanh nhất có thể.',
    'feedback.create_issue': 'Tạo Issue trên GitHub',
    'footer.product': 'Sản Phẩm',
    'footer.support': 'Hỗ Trợ',
    'comparison.title': 'So Sánh Tính Năng',
    'comparison.desc': 'Xem sự khác biệt giữa PHTV và bộ gõ mặc định.',
    'comp.feature': 'Tính năng',
    'comp.default': 'macOS Mặc định',
    'comp.row1': 'Sửa lỗi gõ dấu gạch chân',
    'comp.row2': 'Tốc độ phản hồi',
    'comp.fast': 'Rất nhanh (Swift)',
    'comp.avg': 'Trung bình',
    'comp.row3': 'Kiểm tra chính tả',
    'comp.row4': 'Gõ tắt (Macro)',
    'comp.row5': 'Mã nguồn mở',
    'donate.title': 'Cảm ơn bạn đã ủng hộ!',
    'donate.desc': 'Sự đóng góp của bạn giúp duy trì và phát triển dự án.',
    'donate.close': 'Đóng',
  },
  en: {
    'nav.features': 'Features',
    'nav.setup': 'Install',
    'nav.faq': 'FAQ',
    'nav.contact': 'Contact',
    'nav.comparison': 'Compare',
    'hero.title':
      "Vietnamese Input <span class='text-gradient'>Optimized</span> for macOS",
    'hero.desc':
      'Open-source input method designed for Apple Silicon. Zero latency, Native UI, absolute security.',
    'hero.open_source': 'Open Source',
    'hero.download': 'Download for macOS',
    'hero.donate': 'Support Author',
    'features.title': 'Why PHTV?',
    'features.desc': 'Designed to overcome default input method limitations, providing the smoothest typing experience.',
    'feat1.title': 'High Performance',
    'feat1.desc': 'Pure Swift, no heavy frameworks. Instant response, no lag when typing fast, optimized for M1/M2/M3.',
    'feat2.title': 'Absolute Security',
    'feat2.desc': '100% Open Source on GitHub. No data collection, 100% offline.',
    'feat3.title': 'Native macOS UI',
    'feat3.desc': 'Dark Mode support and beautiful transparent interface.',
    'feat4.title': 'Deep Customization',
    'feat4.desc': 'Full support for Telex, VNI, Simple Telex. Define shortcuts and smart macros.',
    'feat5.title': 'Full Compatibility',
    'feat5.desc': 'Stable on all apps: Microsoft Office, Adobe Creative Cloud, VS Code, Chrome, Safari and IDEs. Fixes underline bug.',
    'gallery.title': 'Application Interface',
    'gallery.desc': "Explore PHTV's modern and intuitive interface",
    'gallery.img1': 'Input Method & Charset',
    'gallery.img2': 'Menu Bar - Input Method',
    'gallery.img3': 'Macro Manager',
    'gallery.img4': 'Advanced Settings',
    'gallery.img5': 'Interface Customization',
    'gallery.img6': 'System Settings',
    'gallery.img7': 'Custom Shortcuts',
    'gallery.img8': 'Menu Bar - Charset',
    'setup.title': 'Installation Guide',
    'step1.title': 'Drag to Applications',
    'step1.desc': 'Open DMG file and drag PHTV to Applications folder.',
    'step2.title': 'Click Open',
    'step2.desc': 'Open PHTV for the first time and click "Open" to confirm.',
    'step3.title': 'Grant Permission',
    'step3.desc': 'Click "Grant Permission" to allow PHTV to work.',
    'step4.title': 'Open System Settings',
    'step4.desc': 'Select "Open System Settings" to access permission settings.',
    'step5.title': 'Enable Accessibility',
    'step5.desc': 'Enable accessibility for PHTV in System Settings. Done!',
    'faq.title': 'FAQ',
    q1: 'Is PHTV free?',
    a1: 'Yes, PHTV is completely free and open source (GPLv3).',
    q2: 'System requirements?',
    a2: 'macOS 14.0 (Sonoma) or later. Best for Apple Silicon (M1/M2/M3/M4).',
    q3: 'Does PHTV collect data?',
    a3: 'No. PHTV works completely offline, no internet connection, no data sent.',
    'feedback.title': 'Feedback & Bug Report',
    'feedback.desc': 'Your feedback helps improve PHTV.',
    'feedback.github_title': 'Report via GitHub Issues',
    'feedback.github_desc': 'Create an issue on GitHub to report bugs or suggest new features. We will respond as soon as possible.',
    'feedback.create_issue': 'Create Issue on GitHub',
    'footer.product': 'Product',
    'footer.support': 'Support',
    'comparison.title': 'Feature Comparison',
    'comparison.desc': 'See the difference between PHTV and default input.',
    'comp.feature': 'Feature',
    'comp.default': 'macOS Default',
    'comp.row1': 'Fix underline bug',
    'comp.row2': 'Response speed',
    'comp.fast': 'Very Fast (Swift)',
    'comp.avg': 'Average',
    'comp.row3': 'Spell Check',
    'comp.row4': 'Macros',
    'comp.row5': 'Open Source',
    'donate.title': 'Thank you for your support!',
    'donate.desc': 'Your contribution helps maintain and develop the project.',
    'donate.close': 'Close',
  },
};

let currentLang = localStorage.getItem('phtv_lang') || 'vi';

function setLanguage(lang) {
  currentLang = lang;
  localStorage.setItem('phtv_lang', lang);
  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    if (translations[lang][key]) el.innerHTML = translations[lang][key];
  });
  const btn = document.getElementById('lang-btn');
  const btnMobile = document.getElementById('lang-btn-mobile');
  if (btn) btn.innerText = lang === 'vi' ? 'EN' : 'VI';
  if (btnMobile) btnMobile.innerText = lang === 'vi' ? 'English' : 'Tiếng Việt';
}
function toggleLanguage() {
  setLanguage(currentLang === 'vi' ? 'en' : 'vi');
}
setLanguage(currentLang);

// Theme Toggle
const themeBtn = document.getElementById('theme-btn');
const mobileThemeBtn = document.getElementById('theme-btn-mobile');

function getSystemTheme() {
  return window.matchMedia('(prefers-color-scheme: dark)').matches
    ? 'dark'
    : 'light';
}

function setTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('phtv_theme', theme);
  updateThemeUI(theme);
}

function updateThemeUI(theme) {
  const icon = theme === 'dark' ? 'light_mode' : 'dark_mode';
  if (themeBtn)
    themeBtn.innerHTML = `<span class="material-icons-round">${icon}</span>`;
  if (mobileThemeBtn)
    mobileThemeBtn.innerText =
      theme === 'dark' ? 'Giao diện: Sáng' : 'Giao diện: Tối';
}

function initTheme() {
  const savedTheme = localStorage.getItem('phtv_theme');
  if (savedTheme) {
    setTheme(savedTheme);
  } else {
    const systemTheme = getSystemTheme();
    document.documentElement.setAttribute('data-theme', systemTheme);
    updateThemeUI(systemTheme);
  }
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme');
  const newTheme = current === 'dark' ? 'light' : 'dark';
  setTheme(newTheme);
}

window
  .matchMedia('(prefers-color-scheme: dark)')
  .addEventListener('change', (e) => {
    if (!localStorage.getItem('phtv_theme')) {
      const newTheme = e.matches ? 'dark' : 'light';
      document.documentElement.setAttribute('data-theme', newTheme);
      updateThemeUI(newTheme);
    }
  });

initTheme();

// Interactions
function toggleMenu() {
  document.getElementById('mobileMenu').classList.toggle('active');
}
function openDonate() {
  document.getElementById('donateModal').classList.add('active');
}
function closeDonate() {
  document.getElementById('donateModal').classList.remove('active');
}

function openLightbox(src) {
  const lb = document.getElementById('galleryLightbox');
  lb.querySelector('img').src = src;
  lb.classList.add('active');
}
function closeLightbox() {
  document.getElementById('galleryLightbox').classList.remove('active');
}

// Scroll Spy
const sections = document.querySelectorAll('section');
const navLinks = document.querySelectorAll('.nav-link');

// Animations
const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) entry.target.classList.add('active');
    });
  },
  { threshold: 0.1 }
);
document.querySelectorAll('.reveal').forEach((el) => observer.observe(el));

// Navbar Scroll Effect
const navbar = document.querySelector('.navbar');

// Card Glow Effect (follow mouse)
document.querySelectorAll('.bento-card').forEach((card) => {
  card.addEventListener('mousemove', (e) => {
    const rect = card.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * 100;
    const y = ((e.clientY - rect.top) / rect.height) * 100;
    card.style.setProperty('--mouse-x', x + '%');
    card.style.setProperty('--mouse-y', y + '%');
  });
});

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
  anchor.addEventListener('click', function (e) {
    const href = this.getAttribute('href');
    if (href !== '#') {
      e.preventDefault();
      const target = document.querySelector(href);
      if (target) {
        const navbarHeight = 100;
        const targetPosition =
          target.getBoundingClientRect().top +
          window.pageYOffset -
          navbarHeight;
        window.scrollTo({ top: targetPosition, behavior: 'smooth' });
      }
    }
  });
});

// Keyboard shortcut for theme toggle (Ctrl/Cmd + Shift + D)
document.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'D') {
    e.preventDefault();
    toggleTheme();
  }
});

// Close modals on Escape key
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    closeDonate();
    closeLightbox();
    document.getElementById('mobileMenu').classList.remove('active');
  }
});

// Scroll to Top Button
const scrollTopBtn = document.getElementById('scrollTop');
function scrollToTop() {
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

// Timeline Animation
const timelineObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry, index) => {
      if (entry.isIntersecting) {
        setTimeout(() => {
          entry.target.classList.add('active');
        }, index * 150);
      }
    });
  },
  { threshold: 0.2 }
);
document
  .querySelectorAll('.timeline-item')
  .forEach((item) => timelineObserver.observe(item));

// Gallery Filter System
const galleryTabs = document.querySelectorAll('.gallery-tab');
const galleryCards = document.querySelectorAll('.gallery-card');

galleryTabs.forEach((tab) => {
  tab.addEventListener('click', () => {
    galleryTabs.forEach((t) => t.classList.remove('active'));
    tab.classList.add('active');

    const filter = tab.dataset.filter;

    galleryCards.forEach((card) => {
      const category = card.dataset.category;
      if (filter === 'all' || category === filter) {
        card.classList.remove('hidden');
        card.style.animation = 'fadeIn 0.3s ease forwards';
      } else {
        card.classList.add('hidden');
      }
    });
  });
});

// Debounced scroll handler for better performance
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// Optimized scroll handlers
const handleScroll = debounce(() => {
  const currentScroll = window.pageYOffset;

  // Navbar effect
  if (currentScroll > 50) {
    navbar.classList.add('scrolled');
  } else {
    navbar.classList.remove('scrolled');
  }

  // Scroll to top button
  if (scrollTopBtn) {
    if (currentScroll > 500) {
      scrollTopBtn.classList.add('visible');
    } else {
      scrollTopBtn.classList.remove('visible');
    }
  }

  // Scroll spy
  let current = '';
  sections.forEach((section) => {
    const sectionTop = section.offsetTop;
    if (currentScroll >= sectionTop - 150) {
      current = section.getAttribute('id');
    }
  });
  navLinks.forEach((link) => {
    link.classList.remove('active');
    if (
      link.getAttribute('href') &&
      link.getAttribute('href').includes(current)
    ) {
      link.classList.add('active');
    }
  });
}, 10);

// Replace multiple scroll listeners with single optimized one
window.addEventListener('scroll', handleScroll, { passive: true });

// Preload critical images
const preloadImages = () => {
  const criticalImages = [
    'Resources/icon.png',
    'Resources/UI/setting_bogo.png',
  ];
  criticalImages.forEach((src) => {
    const img = new Image();
    img.src = src;
  });
};

// Run after DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', preloadImages);
} else {
  preloadImages();
}

// Auto close mobile menu when clicking link
document.querySelectorAll('.mobile-menu a').forEach((link) => {
  link.addEventListener('click', () => {
    document.getElementById('mobileMenu').classList.remove('active');
  });
});

// ============================================
// SERVICE WORKER REGISTRATION (PWA Support)
// ============================================
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register('/PHTV/sw.js')
      .then((registration) => {
        console.log('[App] Service Worker registered successfully:', registration.scope);

        // Check for updates periodically
        setInterval(() => {
          registration.update();
        }, 60 * 60 * 1000); // Check every hour

        // Handle service worker updates
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing;

          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              // New service worker available, notify user
              console.log('[App] New version available! Please refresh.');

              // Optional: Show update notification to user
              if (confirm('Có phiên bản mới của PHTV! Tải lại trang để cập nhật?')) {
                newWorker.postMessage({ type: 'SKIP_WAITING' });
                window.location.reload();
              }
            }
          });
        });
      })
      .catch((error) => {
        console.error('[App] Service Worker registration failed:', error);
      });

    // Listen for controller changes
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      console.log('[App] Service Worker controller changed, reloading page...');
      window.location.reload();
    });
  });
}

// ============================================
// INSTALL PROMPT (PWA Install Banner)
// ============================================
let deferredPrompt;

window.addEventListener('beforeinstallprompt', (e) => {
  // Prevent the default browser install prompt
  e.preventDefault();

  // Store the event for later use
  deferredPrompt = e;

  console.log('[App] PWA install prompt available');

  // Optional: Show custom install button
  // You can create a custom button to trigger installation
});

// Optional: Function to trigger PWA installation
function installPWA() {
  if (deferredPrompt) {
    deferredPrompt.prompt();

    deferredPrompt.userChoice.then((choiceResult) => {
      if (choiceResult.outcome === 'accepted') {
        console.log('[App] User accepted PWA install');
      } else {
        console.log('[App] User dismissed PWA install');
      }
      deferredPrompt = null;
    });
  }
}

// Track PWA installation
window.addEventListener('appinstalled', () => {
  console.log('[App] PWA installed successfully');
  deferredPrompt = null;
});
