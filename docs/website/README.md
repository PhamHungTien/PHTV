# PHTV Website

Project website hosted on GitHub Pages at https://phamhungtien.github.io/PHTV/

## Structure

- `index.html` - Homepage
- `donate.html` - Donation/sponsor page
- `privacy.html` - Privacy policy
- `appcast.xml` - Sparkle update feed (stable releases)
- `appcast-beta.xml` - Sparkle beta update feed
- `Resources/` - Images, icons, and assets

## Sparkle Update Feed

The `appcast.xml` and `appcast-beta.xml` files are used by Sparkle framework for auto-updates.

**Note**: These files are also copied to `docs/` root level to ensure GitHub Pages can serve them at the correct URL path.

### Maintaining appcast.xml

When releasing a new version:

1. **Update version info** in `appcast.xml`:
   ```xml
   <sparkle:version>BUILD_NUMBER</sparkle:version>
   <sparkle:shortVersionString>VERSION</sparkle:shortVersionString>
   ```

2. **Add release notes** in CDATA section

3. **Update enclosure** with DMG info:
   ```xml
   <enclosure
       url="https://github.com/PhamHungTien/PHTV/releases/download/vVERSION/PHTV-VERSION.dmg"
       sparkle:edSignature="SIGNATURE"
       length="FILE_SIZE"
       type="application/octet-stream" />
   ```

4. **Copy to docs root**:
   ```bash
   cp docs/website/appcast.xml docs/appcast.xml
   cp docs/website/appcast-beta.xml docs/appcast-beta.xml
   ```

### Generating EdDSA signature

```bash
./scripts/sign_update.sh Releases/VERSION/PHTV-VERSION.dmg
```

This outputs the signature to include in `<sparkle:edSignature>`.

## Deployment

The website is automatically deployed via GitHub Pages from the `docs/` directory.

Changes pushed to `main` branch will be live within a few minutes.

## Local Testing

```bash
cd docs/website
python3 -m http.server 8000
open http://localhost:8000
```

---

Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
