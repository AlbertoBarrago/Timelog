import type { VercelRequest, VercelResponse } from '@vercel/node'
import { getDb, checkApiKey } from './_db'

// Vercel max function duration — SSE connections are held open up to this limit;
// the Swift client reconnects automatically on disconnect.
export const config = { maxDuration: 300 }

// GET /api/events?userId=<id>
// Server-Sent Events stream. Sends a { type: 'change', collection } event whenever
// any document in the timelog database changes. The client pulls fresh data on receipt;
// no document payload is included here to keep the stream lightweight and avoid leaking
// other users' data through the streaming channel.
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!checkApiKey(req)) return res.status(401).json({ error: 'Unauthorized' })
  if (req.method !== 'GET') return res.status(405).end()

  const userId = typeof req.query.userId === 'string' ? req.query.userId : undefined
  if (!userId) return res.status(400).json({ error: 'userId required' })

  res.setHeader('Content-Type', 'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache, no-transform')
  res.setHeader('Connection', 'keep-alive')
  // Disable proxy/nginx buffering so events are flushed immediately.
  res.setHeader('X-Accel-Buffering', 'no')
  res.flushHeaders()

  const send = (data: object) => {
    if (res.writableEnded) return
    try {
      res.write(`data: ${JSON.stringify(data)}\n\n`)
    } catch {
      // Socket already closed — cleanup will fire via 'close' event below.
    }
  }

  const db = await getDb()
  // Watch the entire database; the client pulls scoped by userId on any event.
  const stream = db.watch()

  send({ type: 'connected' })

  const heartbeat = setInterval(() => send({ type: 'heartbeat' }), 25_000)

  stream.on('change', (change) => {
    send({ type: 'change', collection: change.ns?.coll ?? 'unknown' })
  })

  stream.on('error', () => {
    // Notify the client so it reconnects immediately rather than waiting for the
    // next heartbeat timeout.
    send({ type: 'error' })
    cleanup()
  })

  let cleaned = false
  const cleanup = () => {
    if (cleaned) return
    cleaned = true
    clearInterval(heartbeat)
    stream.close().catch(() => {})
  }

  req.on('close', cleanup)
  res.on('close', cleanup)
}
