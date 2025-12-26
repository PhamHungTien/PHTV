# GitHub Pages Setup

## Current Issue

appcast.xml returns 404 because GitHub Pages is not configured correctly.

## Fix GitHub Pages Settings

### Option 1: Via GitHub Web (Recommended)

1. Go to: https://github.com/PhamHungTien/PHTV/settings/pages

2. **Source** section:
   - Branch: `main`
   - Folder: `/docs` ✅ (IMPORTANT!)
   - Click **Save**

3. Wait 1-2 minutes for deployment

4. Verify:
   ```bash
   curl -I https://phamhungtien.github.io/PHTV/appcast.xml
   # Should return: HTTP/2 200
   ```

### Option 2: Via Command Line

```bash
# This requires gh CLI with repo admin access
gh api repos/PhamHungTien/PHTV/pages \
  --method PUT \
  --field source[branch]=main \
  --field source[path]=/docs
```

## Current Structure

```
docs/
├── appcast.xml          ← Must be accessible at root URL
├── appcast-beta.xml     ← Must be accessible at root URL
└── website/
    ├── index.html      ← Homepage
    ├── donate.html
    └── ...
```

## Expected URLs

After GitHub Pages is configured with `/docs`:

- ✅ `https://phamhungtien.github.io/PHTV/` → `docs/website/index.html`
- ✅ `https://phamhungtien.github.io/PHTV/appcast.xml` → `docs/appcast.xml`
- ✅ `https://phamhungtien.github.io/PHTV/donate.html` → `docs/website/donate.html`

## Alternative: Use .nojekyll

If you want GitHub Pages to serve from a different structure:

1. Create `.nojekyll` file in `docs/`:
   ```bash
   touch docs/.nojekyll
   git add docs/.nojekyll
   git commit -m "Add .nojekyll for GitHub Pages"
   git push
   ```

2. This tells GitHub Pages not to process Jekyll, serving files as-is

## Verification

After fixing GitHub Pages settings:

```bash
# Check homepage
curl -I https://phamhungtien.github.io/PHTV/

# Check appcast
curl -I https://phamhungtien.github.io/PHTV/appcast.xml

# Both should return HTTP/2 200
```

## Troubleshooting

### Still 404 after changing settings?

1. Check GitHub Actions tab for deployment status
2. Wait 2-3 minutes for CDN cache to clear
3. Force refresh: `curl -H "Cache-Control: no-cache" URL`

### Wrong files being served?

- Ensure branch is `main`
- Ensure folder is `/docs` (not `/` or `/docs/website`)
- Check `.nojekyll` file exists if using custom structure

---

**Next Steps**: Go to https://github.com/PhamHungTien/PHTV/settings/pages and set folder to `/docs`
