# Build compatibility

## Toolchain and deployment targets

Development currently uses Xcode 27.1 (build 27A9275). Compatibility with older Xcode versions, including Xcode 16.4, is not guaranteed.

The current app deployment targets are iOS 26.0 and macOS 26.4. The iOS test targets specify iOS 26.4, so running the full test suite requires a matching or newer runtime even though the app targets iOS 26.0.

TimelogCore separately declares Swift tools 6.0 and minimum platforms of iOS 17 / macOS 14. Those are package requirements, not the supported minimum OS versions of the apps.

## Verification — 2026-10-20

Using Xcode 27.1, both Debug builds completed successfully without source changes or code signing:

```bash
xcodebuild -project TimelogMac.xcodeproj -scheme TimelogMac \
  -configuration Debug -destination 'generic/platform=macOS' \
  -derivedDataPath /tmp/timelog-compatibility-check CODE_SIGNING_ALLOWED=NO build

xcodebuild -project Timelog.xcodeproj -scheme Timelog \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/timelog-ios26-check CODE_SIGNING_ALLOWED=NO build
```

The simulator build used the installed iOS Simulator 27.1 SDK. After CoreSimulator refreshed its outdated service, the app was installed and launched on an iPhone 17 simulator running iOS 26.5. A screenshot confirmed the onboarding screen and notification permission prompt; the app process remained running at the subsequent check.

All 55 TimelogCore tests in 14 suites passed using:

```bash
swift test --package-path TimelogCore --scratch-path /tmp/timelog-compatibility-tests
```

This is a build and launch smoke check, not a full functional acceptance test. iOS 26.0 specifically and physical devices were not tested. Timer workflows, notification delivery, Live Activities and persistence across relaunches still require separate functional checks.

## Timelog 2.0.0 report with Xcode 16.4

A user reported this compilation error in `HistoryMacView.swift` when building version 2.0.0 with Xcode 16.4:

```text
Result builder 'ChartContentBuilder' does not implement any 'buildBlock' or a combination of 'buildPartialBlock(first:)' and 'buildPartialBlock(accumulated:next:)' with sufficient availability for this call site
```

The user reported that adding `import Charts` to that file allowed the build to complete. This workaround has not been independently reproduced with Xcode 16.4. It does not establish full compatibility with that toolchain.

The project enables `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`. An import visibility interaction is a possible explanation, but the exact cause remains unverified. No third-party state-management dependency is needed to describe or reproduce the reported project configuration.
