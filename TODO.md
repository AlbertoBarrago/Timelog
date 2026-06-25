# TODO

## Post-release checks

- Try the `Per oggi basta` flow in real use: active session, no active session, already closed day.
- Verify that the `Giornata chiusa` row in Today is clear without being intrusive.
- Check the `Chiusure giornata` Stats card with a few days of real data.
- Evaluate whether the mood labels feel right or should become more restrained/configurable.
- Manually test sync after closing a day: primary Mac -> pull on another Mac, if available.
- Prepare short release notes for this version.
- Verify notification permission behavior after a Sparkle update and note whether the prompt appears again.

## Next steps

- [x] Make `NotificationManager.requestPermission()` more cautious: check status first and request authorization only when `.notDetermined`.
- Introduce a dedicated SwiftData `DayReview` model for mood, pressure, and end-of-day notes.
- Migrate current closures read from `TimeEntry.notes` into `DayReview`.
- Update the sync server and DTOs to sync `DayReview`.
- Add tests for end-of-day closure parsing/migration.
- Design a lightweight `Appunti di oggi` section connected to day closure.
- Evaluate manual export to macOS Notes after `DayReview` is stable.
- Keep iOS in maintenance mode: green build, no new features except compatibility.

## Distribution

- Evaluate Apple Developer Program / Developer ID for stable signing and notarization.
- If we stay on ad-hoc signing, document clearly that macOS may ask for some permissions again after updates.
