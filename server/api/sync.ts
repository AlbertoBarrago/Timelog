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
  deletedAt?: string
  updatedAt?: string
}

interface DayReviewDTO {
  _id: string
  date?: string
  mood?: string
  pressure?: number
  notes?: string
  userId?: string
  deletedAt?: string
}

interface SyncPayload {
  userId?:  string
  clients:  ClientDTO[]
  projects: ProjectDTO[]
  entries:  EntryDTO[]
  sessions: SessionDTO[]
  dayReviews?: DayReviewDTO[]
}

// POST /api/sync — bulk upsert all collections
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!checkApiKey(req)) return res.status(401).json({ error: 'Unauthorized' })
  if (req.method !== 'POST') return res.status(405).end()

  const { userId, clients = [], projects = [], entries = [], sessions = [], dayReviews = [] } = req.body as SyncPayload
  const db = await getDb()

  const toOid = (id: string) => ObjectId.isValid(id) ? new ObjectId(id) : new ObjectId()

  // Sessions are pushed by every device that holds a live copy of a running
  // session, so two devices can race: one stops the session while the other,
  // unaware, re-pushes its stale "still active" snapshot. A plain upsert would
  // let whichever push lands last win outright. Guard with `updatedAt` so a
  // write only applies when it's at least as new as what's stored — a stale
  // write's filter won't match the existing document and, with upsert on,
  // collides on `_id` instead of silently overwriting it. That collision
  // (Mongo error code 11000) is the expected outcome for a stale write.
  const sessionUpserts = Promise.allSettled(
    sessions.map(s => {
      const updatedAt = s.updatedAt ? new Date(s.updatedAt) : new Date()
      return db.collection('active_sessions').updateOne(
        {
          _id: toOid(s._id),
          $or: [{ updatedAt: { $exists: false } }, { updatedAt: { $lte: updatedAt } }],
        },
        {
          $set: {
            startDate: s.startDate ? new Date(s.startDate) : new Date(),
            notes: s.notes ?? null,
            label: s.label ?? null,
            clientMongoId: s.clientMongoId ?? null,
            projectMongoId: s.projectMongoId ?? null,
            notificationID: s.notificationID ?? '',
            userId: s.userId,
            deletedAt: s.deletedAt ?? null,
            updatedAt,
          },
        },
        { upsert: true }
      )
    })
  )

  const [, sessionResults] = await Promise.all([
    Promise.all([
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
      ...dayReviews.map(r =>
        db.collection('day_reviews').updateOne(
          { _id: toOid(r._id) },
          { $set: { date: r.date ? new Date(r.date) : new Date(), mood: r.mood ?? null, pressure: r.pressure ?? null, notes: r.notes ?? null, userId: r.userId, deletedAt: r.deletedAt ?? null } },
          { upsert: true }
        )
      ),
    ]),
    sessionUpserts,
  ])

  const sessionError = sessionResults.find(
    r => r.status === 'rejected' && (r.reason as { code?: number } | undefined)?.code !== 11000
  )
  if (sessionError && sessionError.status === 'rejected') throw sessionError.reason

  res.json({ ok: true })
}
