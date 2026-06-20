# Self-Hosting Guide

This guide explains how to set up your own Timelog infrastructure from scratch — your own MongoDB Atlas cluster and your own Vercel sync server.

Each person who runs Timelog identifies themselves with a **nickname** chosen on first launch. All their data (clients, projects, time entries) is stored under that nickname and is invisible to other users, even if they share the same Atlas cluster.

---

## What you need

- A [MongoDB Atlas](https://www.mongodb.com/atlas) account (free tier M0 is sufficient)
- A [Vercel](https://vercel.com) account (free Hobby plan is fine for personal use)
- Node.js installed locally (for deploying the server)
- The Timelog repo cloned

---

## Step 1 — Create a MongoDB Atlas cluster

1. Log in to [cloud.mongodb.com](https://cloud.mongodb.com)
2. Create a new project (e.g. "timelog")
3. Build a free **M0** cluster (any region)
4. In **Database Access**, create a user with **readWrite** on the `timelog` database
5. In **Network Access**, add your IP address (or `0.0.0.0/0` for development)
6. In **Connect**, choose **Connect your application** and copy the connection string

It will look like:
```
mongodb+srv://username:password@cluster0.abc123.mongodb.net
```

---

## Step 2 — Create the collections and indexes

Run the setup script with `mongosh`:

```bash
mongosh "mongodb+srv://username:password@cluster0.abc123.mongodb.net/timelog" \
  server/setup-mongo.js
```

The script creates the four collections and the required indexes (including `userId` for per-user isolation).

---

## Step 3 — Deploy the Vercel sync server

The iOS and macOS apps do not connect to MongoDB directly. Both use a lightweight REST + SSE API deployed on Vercel.

```bash
cd server
npm install
vercel login
vercel deploy --prod
```

Note the deployment URL (e.g. `https://timelog-server-yourname.vercel.app`).

Then set the environment variables on Vercel:

```bash
vercel env add MONGODB_URI production
# paste your Atlas connection string when prompted

vercel env add API_KEY production
# choose a random secret key, e.g.: openssl rand -hex 32
```

Redeploy after adding the variables:

```bash
vercel deploy --prod
```

---

## Step 4 — Configure the Mac app

Create the config file with your Vercel URL and API key:

```bash
mkdir -p ~/.config/timelog
cat > ~/.config/timelog/sync.local << 'EOF'
URL=https://timelog-server-yourname.vercel.app
API_KEY=your-secret-key
EOF
chmod 600 ~/.config/timelog/sync.local
```

Launch the Mac app. It reads the file, saves the credentials to Keychain, and pulls your data.

---

## Step 5 — Configure the iOS app

Create the sync config file that the iOS bundle reads:

```
Timelog/SyncConfig.local
```

Contents:
```
URL=https://timelog-server-yourname.vercel.app
API_KEY=your-secret-key
```

> This file is gitignored. Never commit it. The app reads it on first launch and saves the values to Keychain automatically.

---

## Adding a teammate

Each teammate:
1. Gets the same Vercel URL + API key
2. Chooses their own nickname on first launch
3. Their data is isolated — they will not see your clients or time entries

No extra setup is needed on Atlas — one cluster, one database, multiple users.
