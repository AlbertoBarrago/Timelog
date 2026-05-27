import type { VercelRequest, VercelResponse } from '@vercel/node'
import { getDb, checkApiKey } from './_db'
import { ObjectId } from 'mongodb'

interface ClientDTO {
  _id: string
  name: string
  colorHex: string
  isArchived: boolean
  userId?: string
  deletedAt?: string
}

interface ProjectDTO {
  _id: string
  name: string
  code?: string
  isArchived: boolean
  clientMongoId?: string
  labels?: string[]
  userId?: string
  deletedAt?: string
}

interface EntryDTO {
  _id: string
  date: string
  durationMinutes: number
  notes?: string
  label?: string
  clientMongoId?: string
  projectMongoId?: string
  userId?: string
  deletedAt?: string
}

interface SessionDTO {
  _id: string
  startDate?: string
  notes?: string
  label?: string
  clientMongoId?: string
  projectMongoId?: string
  notificationID?: string
  userId?: string
}

interface SyncPayload {
  clients:  ClientDTO[]
  projects: ProjectDTO[]
  entries:  EntryDTO[]
  sessions: SessionDTO[]
}

// POST /api/sync — bulk upsert all collections
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!checkApiKey(req)) return res.status(401).json({ error: 'Unauthorized' })
  if (req.method !== 'POST') return res.status(405).end()

  const { clients = [], projects = [], entries = [], sessions = [] } = req.body as SyncPayload
  const db = await getDb()

  const toOid = (id: string) => ObjectId.isValid(id) ? new ObjectId(id) : new ObjectId()

  await Promise.all([
    ...clients.map(c =>
      db.collection('clients').updateOne(
        { _id: toOid(c._id) },
        { $set: { name: c.name, colorHex: c.colorHex, isArchived: c.isArchived, userId: c.userId, deletedAt: c.deletedAt ?? null } },
        { upsert: true }
      )
    ),
    ...projects.map(p =>
      db.collection('projects').updateOne(
        { _id: toOid(p._id) },
        { $set: { name: p.name, code: p.code ?? null, isArchived: p.isArchived, clientMongoId: p.clientMongoId ?? null, labels: p.labels ?? [], userId: p.userId, deletedAt: p.deletedAt ?? null } },
        { upsert: true }
      )
    ),
    ...entries.map(e =>
      db.collection('time_entries').updateOne(
        { _id: toOid(e._id) },
        { $set: { date: new Date(e.date), durationMinutes: e.durationMinutes, notes: e.notes ?? null, label: e.label ?? null, clientMongoId: e.clientMongoId ?? null, projectMongoId: e.projectMongoId ?? null, userId: e.userId, deletedAt: e.deletedAt ?? null } },
        { upsert: true }
      )
    ),
    ...sessions.map(s =>
      db.collection('active_sessions').updateOne(
        { _id: toOid(s._id) },
        { $set: { startDate: s.startDate ? new Date(s.startDate) : new Date(), notes: s.notes ?? null, label: s.label ?? null, clientMongoId: s.clientMongoId ?? null, projectMongoId: s.projectMongoId ?? null, notificationID: s.notificationID ?? '', userId: s.userId } },
        { upsert: true }
      )
    ),
  ])

  res.json({ ok: true })
}
