# TODO

## Next steps

- [x] Make `NotificationManager.requestPermission()` more cautious: check status first and request authorization only when `.notDetermined`.
- [x] Add a greetings during the day, so the user knows when the day starts.
- [x] Introduce a dedicated SwiftData `DayReview` model for mood, pressure, and end-of-day notes.
- Migrate current closures read from `TimeEntry.notes` into `DayReview`.
- [x] Update the sync server and DTOs to sync `DayReview`.
- Add tests for end-of-day closure parsing/migration.
- Design a lightweight `Appunti di oggi` section connected to day closure.
- Evaluate manual export to macOS Notes after `DayReview` is stable.
- Keep iOS in maintenance mode: green build, no new features except compatibility.
