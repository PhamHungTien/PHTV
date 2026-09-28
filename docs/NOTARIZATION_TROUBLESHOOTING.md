# Notarization troubleshooting

This checklist follows Apple's notarization workflow and Apple DTS guidance for submissions that stay in `In Progress`.

## What `In Progress` means

`In Progress` means Apple has accepted the upload and has not produced a notarization verdict yet. There is no useful notarization log until the submission reaches a completed state such as `Accepted`, `Invalid`, or `Rejected`.

Apple DTS notes that most uploads are notarized quickly, but some uploads can be held for deeper analysis. This is more common for first-time notarization or new Developer ID teams. If it clears, later submissions for the same app/team often complete faster.

## Current PHTV release workflow safeguards

- Uses `Developer ID Application` signing identity only.
- Enables hardened runtime and secure timestamp.
- Re-signs nested Sparkle code, including `Autoupdate`.
- Signs the DMG before submitting it to Apple.
- Submits with `notarytool submit --wait --timeout 5h`; the job has a 360-minute limit.
- Prints `notarytool history` and `notarytool log` on failure.
- Allows up to two architecture jobs (`max-parallel: 2`). Release runs are serialized by the workflow concurrency group, but the two architectures within a run may submit concurrently.

## First diagnosis: run the smoke test

Run GitHub Actions workflow:

```text
Notary Smoke Test
```

Interpretation:

- `Accepted`: Apple account and notary service are working. Investigate the PHTV artifact.
- `Invalid` or `Rejected`: read the printed Apple notary log and fix the listed signing/package issue.
- Still `In Progress`: the issue is likely Apple notary service, team/account onboarding, or deeper analysis, not the PHTV app bundle.

## If PHTV and smoke test both stay `In Progress`

1. Check Apple Developer System Status:
   `https://developer.apple.com/system-status/`
2. Stop rerunning the same release repeatedly for a few hours. Multiple duplicate submissions can make diagnosis noisier.
3. Keep the submission IDs from the GitHub Actions logs.
4. Open Apple Developer Support:
   `https://developer.apple.com/contact/`
5. Use topic:
   `Development and Technical` > `Other Development or Technical Questions`
6. Include:
   - Team ID
   - Apple ID email
   - Workflow run URL
   - Submission IDs
   - `notarytool history` output
   - Confirmation that a minimal signed app also stays `In Progress`

## Useful commands for local follow-up

```bash
xcrun notarytool history \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD"
```

```bash
xcrun notarytool info "$SUBMISSION_ID" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD"
```

```bash
xcrun notarytool log "$SUBMISSION_ID" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD"
```

## Apple support message template

```text
Hello Apple Developer Support,

Our Developer ID notarization submissions are stuck in "In Progress" and no notarization log is available yet.

Team ID: 95AKA2N383
Product: PHTV
GitHub Actions run:
Submission IDs:

We verified:
- Developer ID Application certificate is used.
- Hardened runtime is enabled.
- Secure timestamp is included.
- DMG is signed before submission.
- Nested Sparkle components are signed.
- A minimal signed app submitted by our Notary Smoke Test also remains in "In Progress".

Could the Developer ID Notary Service team check whether our team/account is blocked, waiting for deeper analysis, or not yet configured for notarization?
```
