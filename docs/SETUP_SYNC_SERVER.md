# Sync Server Setup — new machine notes

## iOS — RestSyncService

The iOS app reads sync credentials from a file **inside the Xcode project bundle** (not `~/.config`).

Create `Timelog/SyncConfig.local` at the root of the iOS project (gitignored, already in `.gitignore`):

```
URL=https://timelog-server.vercel.app
API_KEY=YOUR_API_KEY
```

> Replace `YOUR_API_KEY` with the key configured on Vercel.

On first launch the app reads this file and saves URL + API key to Keychain automatically.
No manual input in Settings required.

**Do not use `~/.config/timelog/` for iOS — that path is only for macOS.**

---

## macOS — MongoSyncService

The macOS app reads the MongoDB connection string from `~/.config/timelog/mongo.local`:

```bash
mkdir -p ~/.config/timelog

echo "mongodb+srv://user:password@cluster.mongodb.net" > ~/.config/timelog/mongo.local

chmod 600 ~/.config/timelog/mongo.local
```

On first launch the app reads this file and saves the connection string to Keychain automatically.

---

## Vercel environment variables (already set — for reference only)

The `timelog-server` project on Vercel has these configured:
- `MONGODB_URI` — MongoDB Atlas connection string
- `API_KEY` — secret key shared with the app

To retrieve them: run `vercel env pull` from the `server/` folder.

---

## Quick verification

```bash
curl -s -H "X-API-Key: YOUR_API_KEY" https://timelog-server.vercel.app/api/pull
```

Expected response: `{"clients":[...],"projects":[...],"entries":[...]}`
