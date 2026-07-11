import { z } from 'zod';

export const createSlotSchema = z
  .object({
    title: z.string().min(1),
    startTime: z.string().datetime(),
    endTime: z.string().datetime(),
    capacity: z.number().int().positive(),
  })
  .refine((data) => new Date(data.endTime) > new Date(data.startTime), {
    message: 'endTime must be after startTime',
    path: ['endTime'],
  });

export type CreateSlotInput = z.infer<typeof createSlotSchema>;
