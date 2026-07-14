import { z } from 'zod';

export const createBookingSchema = z.object({
  slotId: z.string().uuid(),
});

export type CreateBookingInput = z.infer<typeof createBookingSchema>;
