import { pool } from './db';

export interface Booking {
  id: string;
  userId: string;
  slotId: string;
  status: 'confirmed' | 'cancelled';
  createdAt: string;
}

function mapRow(row: any): Booking {
  return {
    id: row.id,
    userId: row.user_id,
    slotId: row.slot_id,
    status: row.status,
    createdAt: row.created_at,
  };
}

export async function createBooking(userId: string, slotId: string): Promise<Booking> {
  const result = await pool.query(
    `INSERT INTO bookings (user_id, slot_id)
     VALUES ($1, $2)
     RETURNING *`,
    [userId, slotId],
  );
  return mapRow(result.rows[0]);
}

export async function findBookingById(id: string): Promise<Booking | null> {
  const result = await pool.query('SELECT * FROM bookings WHERE id = $1', [id]);
  if (result.rowCount === 0) return null;
  return mapRow(result.rows[0]);
}

export async function listBookingsForUser(userId: string): Promise<Booking[]> {
  const result = await pool.query(
    'SELECT * FROM bookings WHERE user_id = $1 ORDER BY created_at DESC',
    [userId],
  );
  return result.rows.map(mapRow);
}

export async function cancelBooking(id: string): Promise<Booking | null> {
  const result = await pool.query(
    `UPDATE bookings
     SET status = 'cancelled', updated_at = now()
     WHERE id = $1 AND status = 'confirmed'
     RETURNING *`,
    [id],
  );
  if (result.rowCount === 0) return null;
  return mapRow(result.rows[0]);
}
