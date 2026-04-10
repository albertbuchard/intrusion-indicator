# Intrusion Indicator

Intrusion Indicator is a lightweight macOS menubar utility that surfaces local risk signals about screen capture, microphone/camera exposure, and remote-access tooling in real time.

## Distribution

- App Store release is managed by Fastlane with:
  - `fastlane build_appstore`
  - `fastlane take_appstore_screenshots`
  - `fastlane release_appstore`
- The screenshot step uses deterministic UITest fixtures and writes `artifacts/screenshots/en-US`.

## Safety Notes

- Green means no configured rule is currently firing.
- Yellow means uncertain visibility or a lower-confidence signal is active.
- Red means stronger exposure signal is active.

## Support

- Review the [faq](./faq.md)
- See [privacy notes](./privacy.md)
- Learn [publishing workflow expectations](./publish.md)
