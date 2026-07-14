import { Router, Response } from 'express';
import { createBookingSchema } from './schemas';
import {
  createBooking,
  findBookingById,
  listBookingsForUser,
  cancelBooking,
} from './bookingRepository';
import { reserveSlot, releaseSlot, SlotFullError } from './availabilityClient';
import { publishBookingEvent } from './messageBus';
import { requireAuth, AuthenticatedRequest } from './authMiddleware';
import { log } from './logger';

const router = Router();

router.use(requireAuth);

/**
 * Creating a booking is a multi-step operation across two services and a
 * database, which is exactly where distributed systems get hard:
 *
 *   1. Reserve a spot in availability-service (external call)
 *   2. Insert the booking row here (local DB write)
 *   3. Publish a booking.created event (best-effort, never blocks)
 *
 * Step 1 and step 2 are NOT wrapped in a single atomic transaction -
 * they're two separate systems, so classic ACID transactions don't span
 * them. If step 1 succeeds but step 2 fails (e.g. the unique constraint
 * rejects a duplicate booking, or this process crashes mid-request), we'd
 * be left with a slot marked as reserved but no booking record pointing
 * to it - a real inconsistency.
 *
 * The fix is a "compensating action": if step 2 fails after step 1
 * already succeeded, we explicitly undo step 1 by releasing the slot
 * again. This is a lightweight version of the Saga pattern used in
 * production microservices to keep multi-service operations consistent
 * without distributed transactions.
 */
router.post('/bookings', async (req: AuthenticatedRequest, res: Response) => {
  const parsed = createBookingSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { slotId } = parsed.data;
  const identity = { userId: req.user!.sub, email: req.user!.email, role: req.user!.role };

  log(`Booking request from ${identity.email} for slot ${slotId} — calling availability-service...`);

  try {
    await reserveSlot(slotId, identity);
  } catch (err) {
    if (err instanceof SlotFullError) {
      log(`Booking rejected — slot ${slotId} is full`);
      return res.status(409).json({ error: 'This slot is full' });
    }
    console.error('Failed to reserve slot:', err);
    return res.status(502).json({ error: 'Could not reach availability service' });
  }

  let booking;
  try {
    booking = await createBooking(identity.userId, slotId);
    log(`Booking ${booking.id} confirmed for ${identity.email}`);
  } catch (err: any) {
    // Compensating action: the reservation succeeded but the booking
    // record didn't, so we must give the spot back rather than leaving
    // it silently reserved forever.
    log(`Booking record failed after reservation succeeded — releasing slot ${slotId} (compensating action)`);
    await releaseSlot(slotId, identity);

    if (err?.code === '23505') {
      // Postgres unique_violation - this user already has an active
      // booking on this slot (double-click, retry, etc).
      return res.status(409).json({ error: 'You already have a booking for this slot' });
    }
    console.error('Failed to create booking record:', err);
    return res.status(500).json({ error: 'Could not create booking' });
  }

  log(`Publishing booking.created event for booking ${booking.id}...`);
  await publishBookingEvent({
    type: 'booking.created',
    bookingId: booking.id,
    slotId: booking.slotId,
    userId: identity.userId,
    userEmail: identity.email,
    occurredAt: new Date().toISOString(),
  });

  return res.status(201).json({ booking });
});

router.get('/bookings', async (req: AuthenticatedRequest, res: Response) => {
  const bookings = await listBookingsForUser(req.user!.sub);
  return res.status(200).json({ bookings });
});

router.post('/bookings/:id/cancel', async (req: AuthenticatedRequest, res: Response) => {
  const existing = await findBookingById(req.params.id);
  if (!existing) {
    return res.status(404).json({ error: 'Booking not found' });
  }

  // Ownership check: only the booking's owner or an admin can cancel it.
  // Defense in depth again - the gateway wouldn't route someone else's
  // request here, but this service checks anyway.
  if (existing.userId !== req.user!.sub && req.user!.role !== 'admin') {
    return res.status(403).json({ error: 'You cannot cancel this booking' });
  }

  const cancelled = await cancelBooking(req.params.id);
  if (!cancelled) {
    return res.status(409).json({ error: 'Booking is not in a cancellable state' });
  }
  log(`Booking ${cancelled.id} cancelled — releasing slot ${cancelled.slotId}...`);

  const identity = { userId: req.user!.sub, email: req.user!.email, role: req.user!.role };
  await releaseSlot(cancelled.slotId, identity);

  log(`Publishing booking.cancelled event for booking ${cancelled.id}...`);
  await publishBookingEvent({
    type: 'booking.cancelled',
    bookingId: cancelled.id,
    slotId: cancelled.slotId,
    userId: cancelled.userId,
    userEmail: identity.email,
    occurredAt: new Date().toISOString(),
  });

  return res.status(200).json({ booking: cancelled });
});

export default router;
