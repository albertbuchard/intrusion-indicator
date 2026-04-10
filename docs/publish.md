# App Store Publication

## Prerequisites

- Xcode and App Store Connect API key values:
  - `APP_STORE_KEY_ID`
  - `APP_STORE_ISSUER_ID`
  - `APP_STORE_API_KEY_BASE64` (Base64 of the downloaded `.p8`)
- Apple Team and App Store Connect app ID configured via:
  - `APPLE_ID`
  - `APPLE_TEAM_ID`
  - `APP_IDENTIFIER`

## Local Release Steps

1. Run a normal archive build:
   - `bundle exec fastlane build_appstore`
2. Capture deterministic screenshots from the dedicated UITest suite:
   - `bundle exec fastlane take_appstore_screenshots`
   - or run `scripts/capture_appstore_screenshots.sh`
3. Upload metadata, screenshots, and app package:
   - `bundle exec fastlane release_appstore`

## Required Release Setup

- Set the following repository secrets for `release-appstore`:
  - `APP_STORE_KEY_ID`
  - `APP_STORE_ISSUER_ID`
  - `APP_STORE_API_KEY_BASE64`
  - `APPLE_ID`
  - `APPLE_TEAM_ID`
- Fill metadata values under:
  - `fastlane/metadata/en-US/*.txt`
  - `fastlane/metadata/en-US/review_information/*.txt`

## Screenshot Naming

Fastlane writes screenshots in this order:
- `01-overview.png`
- `02-rules.png`
- `03-risk-yellow.png`
- `04-risk-red.png`
- `05-permissions.png`

## What the capture script validates

- Files exist for every required screenshot name
- PNG readability
- Minimum resolution for macOS screenshots (`1024x768`)
- Reasonable App Store-like aspect ratio
