# Timelog — Installation Guide

## Requirements

| What | Minimum version |
|------|-----------------|
| macOS | 14 Sonoma (or later) |
| Xcode | 16+ |
| Git | any recent version |

---

## 1. Clone the repo

```bash
git clone <repo-url> ~/Code/Swift/TimeLog
cd ~/Code/Swift/TimeLog
```

> If the repo is private make sure you have SSH configured or log in with `gh auth login`.

---

## 2. Open the workspace

**Always open `TimeLog.xcworkspace`**, not the individual `.xcodeproj` files.

```bash
open TimeLog.xcworkspace
```

Or drag it into Xcode from Finder.

---

## 3. Configure signing

1. Select the `TimelogMac` project in the Xcode navigator
2. Target **TimelogMac** → **Signing & Capabilities** tab
3. Check **Automatically manage signing**
4. Choose your **Team** (a personal Apple ID works fine)
5. Let Xcode resolve the provisioning profiles automatically

> If you don't have an Apple ID in Xcode: menu **Xcode → Settings → Accounts → +**

---

## 4. Build & Run

Select the **TimelogMac** scheme with your Mac as the destination, then:

```
⌘ R
```

The app launches with both the main window **and** the menu bar icon.

---

## 5. (Optional) Export a `.app` to use without Xcode

1. **Product → Archive** (TimelogMac scheme, "Any Mac" destination)
2. In the Organizer: **Distribute App → Copy App**
3. Save the `.app` where you want (e.g. `~/Desktop/Timelog.app`)
4. Copy `Timelog.app` to `/Applications` on your work Mac

> First launch: right-click → **Open** (bypasses Gatekeeper for non-notarised apps).

---

## 6. First launch — choose your nickname

On first launch the app will ask for a **nickname**. This is a one-time step.

- The nickname is stamped on every record you create
- Pick something short and consistent (e.g. your first name or GitHub handle)
- It is awkward to change once records carry it, so choose carefully

---

## 7. Features available immediately

- **Menu bar** — clock icon always visible, shows the running timer
- **Main window** — `⌘` click the menu bar icon, or open the app normally
- **Preferences** — `⌘,`
- **Data** — saved locally in SwiftData (no account required)

---

## 8. Troubleshooting

| Problem | Solution |
|---------|----------|
| Build error on `TimelogCore` | Xcode → **File → Packages → Reset Package Caches** |
| Signing error "No account" | Add your Apple ID in Xcode Settings → Accounts |
| App blocked by Gatekeeper | Right-click → Open, then confirm |
| Menu bar icon not appearing | Check the app is running in Activity Monitor |
