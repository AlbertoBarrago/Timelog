import type { VercelRequest, VercelResponse } from '@vercel/node'
import { getDb, checkApiKey } from './_db'

// GET /api/pull — returns all collections in one shot
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!checkApiKey(req)) return res.status(401).json({ error: 'Unauthorized' })
  if (req.method !== 'GET') return res.status(405).end()

  const db = await getDb()

  // Scope to the requesting user when a userId is supplied. Legacy documents with a
  // missing/empty userId stay visible (the iOS client also tolerates them client-side).
  const userId = typeof req.query.userId === 'string' ? req.query.userId : undefined
  const scope = userId
    ? { $or: [{ userId }, { userId: { $in: [null, ''] } }, { userId: { $exists: false } }] }
    : {}

  const [clients, projects, entries, sessions, dayReviews] = await Promise.all([
    db.collection('clients').find(scope).toArray(),
    db.collection('projects').find(scope).toArray(),
    db.collection('time_entries').find(scope).toArray(),
    db.collection('active_sessions').find(scope).toArray(),
    db.collection('day_reviews').find(scope).toArray(),
  ])

  res.json({
    clients:  clients.map(d  => ({ ...d,  _id: d._id.toString() })),
    projects: projects.map(d => ({ ...d,  _id: d._id.toString() })),
    entries:  entries.map(d  => ({ ...d,  _id: d._id.toString() })),
    sessions: sessions.map(d => ({ ...d,  _id: d._id.toString() })),
    dayReviews: dayReviews.map(d => ({ ...d, _id: d._id.toString() })),
  })
}
