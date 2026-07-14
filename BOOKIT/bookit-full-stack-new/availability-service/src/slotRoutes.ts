import { Router, Request, Response } from 'express';
import { createSlotSchema } from './schemas';
import {
  createSlot,
  listUpcomingSlots,
  findSlotById,
  reserveSlot,
  releaseSlot,
} from './slotRepository';
import { requireAuth, requireRole, AuthenticatedRequest } from './authMiddleware';
import { log } from './logger';

const router = Router();

// Public: anyone can browse upcoming slots.
router.get('/slots', async (_req: Request, res: Response) => {
  const slots = await listUpcomingSlots();
  res.status(200).json({ slots });
});

router.get('/slots/:id', async (req: Request, res: Response) => {
  const slot = await findSlotById(req.params.id);
  if (!slot) {
    return res.status(404).json({ error: 'Slot not found' });
  }
  return res.status(200).json({ slot });
});

// Admin-only: create a new bookable slot.
router.post('/slots', requireAuth, requireRole('admin'), async (req: Request, res: Response) => {
  const parsed = createSlotSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { title, startTime, endTime, capacity } = parsed.data;
  const slot = await createSlot(title, startTime, endTime, capacity);
  log(`Session created: "${slot.title}" (capacity ${slot.capacity})`);
  return res.status(201).json({ slot });
});

// Internal: called by booking-service when a user books a slot.
// Not exposed to end users directly — in production this route would sit
// behind network policies restricting it to internal service traffic only,
// not just JWT auth.
router.post('/slots/:id/reserve', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  const slot = await reserveSlot(req.params.id);
  if (!slot) {
    log(`Reserve rejected — slot ${req.params.id} is full`);
    return res.status(409).json({ error: 'Slot is full or does not exist' });
  }
  log(`Seat reserved on "${slot.title}" (${slot.bookedCount}/${slot.capacity} now booked)`);
  return res.status(200).json({ slot });
});

// Internal: called by booking-service when a booking is cancelled.
router.post('/slots/:id/release', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  const slot = await releaseSlot(req.params.id);
  if (!slot) {
    log(`Release rejected — nothing to release for slot ${req.params.id}`);
    return res.status(409).json({ error: 'Nothing to release for this slot' });
  }
  log(`Seat released on "${slot.title}" (${slot.bookedCount}/${slot.capacity} now booked)`);
  return res.status(200).json({ slot });
});

export default router;
