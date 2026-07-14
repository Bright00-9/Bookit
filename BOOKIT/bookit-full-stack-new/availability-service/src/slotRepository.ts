import { pool } from './db';

export interface Slot {
  id: string;
  title: string;
  startTime: string;
  endTime: string;
  capacity: number;
  bookedCount: number;
}

function mapRow(row: any): Slot {
  return {
    id: row.id,
    title: row.title,
    startTime: row.start_time,
    endTime: row.end_time,
    capacity: row.capacity,
    bookedCount: row.booked_count,
  };
}

export async function createSlot(
  title: string,
  startTime: string,
  endTime: string,
  capacity: number,
): Promise<Slot> {
  const result = await pool.query(
    `INSERT INTO slots (title, start_time, end_time, capacity)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [title, startTime, endTime, capacity],
  );
  return mapRow(result.rows[0]);
}

export async function listUpcomingSlots(): Promise<Slot[]> {
  const result = await pool.query(
    `SELECT * FROM slots WHERE start_time > now() ORDER BY start_time ASC`,
  );
  return result.rows.map(mapRow);
}

export async function findSlotById(id: string): Promise<Slot | null> {
  const result = await pool.query('SELECT * FROM slots WHERE id = $1', [id]);
  if (result.rowCount === 0) return null;
  return mapRow(result.rows[0]);
}

/**
 * Atomically reserves one spot on a slot.
 *
 * This is the piece that actually prevents double-booking. Two concurrent
 * requests both reading "bookedCount: 4, capacity: 5" and then separately
 * writing "bookedCount: 5" is a classic race condition (read-then-write is
 * not atomic). Instead, we push the capacity check INTO the UPDATE's WHERE
 * clause, so PostgreSQL evaluates and applies it as a single atomic
 * operation. If two requests race for the last spot, the database
 * guarantees only one UPDATE actually matches a row.
 *
 * Returns the updated slot if a spot was reserved, or null if the slot
 * was already full (or didn't exist).
 */
export async function reserveSlot(id: string): Promise<Slot | null> {
  const result = await pool.query(
    `UPDATE slots
     SET booked_count = booked_count + 1, updated_at = now()
     WHERE id = $1 AND booked_count < capacity
     RETURNING *`,
    [id],
  );
  if (result.rowCount === 0) return null;
  return mapRow(result.rows[0]);
}

/**
 * Atomically releases one spot (e.g. on booking cancellation).
 * The `booked_count > 0` guard prevents it from ever going negative,
 * even under concurrent/duplicate release calls.
 */
export async function releaseSlot(id: string): Promise<Slot | null> {
  const result = await pool.query(
    `UPDATE slots
     SET booked_count = booked_count - 1, updated_at = now()
     WHERE id = $1 AND booked_count > 0
     RETURNING *`,
    [id],
  );
  if (result.rowCount === 0) return null;
  return mapRow(result.rows[0]);
}
