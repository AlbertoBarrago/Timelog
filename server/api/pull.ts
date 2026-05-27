import type { VercelRequest, VercelResponse } from '@vercel/node'
import { getDb, checkApiKey } from './_db'

// GET /api/pull — returns all collections in one shot
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!checkApiKey(req)) return res.status(401).json({ error: 'Unauthorized' })
  if (req.method !== 'GET') return res.status(405).end()

  const db = await getDb()
  const [clients, projects, entries, sessions] = await Promise.all([
    db.collection('clients').find().toArray(),
    db.collection('projects').find().toArray(),
    db.collection('time_entries').find().toArray(),
    db.collection('active_sessions').find().toArray(),
  ])

  res.json({
    clients:  clients.map(d  => ({ ...d,  _id: d._id.toString() })),
    projects: projects.map(d => ({ ...d,  _id: d._id.toString() })),
    entries:  entries.map(d  => ({ ...d,  _id: d._id.toString() })),
    sessions: sessions.map(d => ({ ...d,  _id: d._id.toString() })),
  })
}
