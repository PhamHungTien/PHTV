# PHTV Documentation

Comprehensive documentation for PHTV - Modern Vietnamese Input Method for macOS.

## 📚 Documentation Structure

### [Automation](automation/)
Complete automation system for Homebrew releases:
- **[Quick Start](automation/README.md)** - Get started in 5 minutes
- **[GitHub Actions Setup](automation/github-actions.md)** - Automated releases
- **[Workflow Guide](automation/workflow.md)** - Complete workflow documentation
- **[Setup Guide](automation/setup.md)** - Detailed setup instructions

### [Homebrew](homebrew/)
Homebrew Cask installation and maintenance:
- **[User Guide](homebrew/README.md)** - Installation for users
- **[Maintenance Guide](homebrew/maintenance.md)** - Developer guide

### [Website](website/)
Project website source files (HTML/CSS/JS):
- Hosted at: https://phamhungtien.com/
- User documentation, downloads, and guides

## 🔗 Quick Links

- **Main README**: [../README.md](../README.md)
- **Installation Guide**: [../INSTALL.md](../INSTALL.md)
- **FAQ**: [../FAQ.md](../FAQ.md)
- **Contributing**: [../CONTRIBUTING.md](../CONTRIBUTING.md)
- **Changelog**: [../CHANGELOG.md](../CHANGELOG.md)

## 📂 Project Structure

```
PHTV/
├── docs/               # Documentation
│   ├── automation/    # Automation guides
│   ├── homebrew/      # Homebrew docs
│   └── website/       # Project website
├── homebrew/          # Homebrew formula
│   └── phtv.rb       # Cask formula
├── scripts/           # Automation scripts
│   ├── update_homebrew.sh
│   ├── sync_homebrew_tap.sh
│   └── release_homebrew.sh
├── PHTV/              # Source code
└── .github/           # GitHub configurations
    └── workflows/     # GitHub Actions
```

## 🚀 For Developers

### Release Process
1. **Build & Test**: Build app and create DMG
2. **Automation**: Run `./scripts/release_homebrew.sh`
3. **GitHub Release**: Create release on GitHub
4. **Auto-update**: GitHub Actions handles the rest

See [automation/README.md](automation/README.md) for details.

### Contributing
See [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines.

---

**PHTV** - Precision Hybrid Typing Vietnamese
Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
