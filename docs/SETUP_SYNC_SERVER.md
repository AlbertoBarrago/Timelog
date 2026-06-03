# Sync Server Setup — new machine notes

Both iOS and macOS use `RestSyncService` with the same Vercel backend.
Credentials are stored in Keychain and loaded once from a local file on first launch.

---

## iOS

Create `Timelog/SyncConfig.local` at the root of the iOS project (gitignored,
already in `.gitignore`):

```
URL=https://timelog-server.vercel.app
API_KEY=YOUR_API_KEY
```

On first launch the app reads this file and saves URL + API key to Keychain.
No manual input in Settings is required.

---

## macOS

Create `~/.config/timelog/sync.local` (outside the repo, never committed):

```bash
mkdir -p ~/.config/timelog

cat > ~/.config/timelog/sync.local << 'EOF'
URL=https://timelog-server.vercel.app
API_KEY=YOUR_API_KEY
EOF

chmod 600 ~/.config/timelog/sync.local
```

On first launch the app reads this file and saves the credentials to Keychain.

> If you previously had `~/.config/timelog/mongo.local`, the MongoDB connection
> is no longer used. You can delete it.

---

## Vercel environment variables (already set — for reference only)

The `timelog-server` project on Vercel has these configured:
- `MONGODB_URI` — MongoDB Atlas connection string
- `API_KEY` — secret key shared with both apps

To retrieve them: run `vercel env pull` from the `server/` folder.

---

## Quick verification

```bash
# Pull
curl -s -H "X-API-Key: YOUR_API_KEY" \
  "https://timelog-server.vercel.app/api/pull?userId=your-user-id"

# SSE stream (press Ctrl-C to stop)
curl -N -H "X-API-Key: YOUR_API_KEY" \
  "https://timelog-server.vercel.app/api/events?userId=your-user-id"
```

Expected pull response: `{"clients":[...],"projects":[...],"entries":[...],"sessions":[...]}`

Expected SSE: lines like `data: {"type":"connected"}` then `data: {"type":"heartbeat"}` every 25 s.
