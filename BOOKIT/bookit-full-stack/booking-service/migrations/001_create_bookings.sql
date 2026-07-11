CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  slot_id UUID NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'confirmed', -- 'confirmed' | 'cancelled'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings (user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_slot_id ON bookings (slot_id);

-- Prevents the same user from holding two active bookings on the same
-- slot. Note this does NOT prevent overbooking a slot's capacity overall -
-- that's availability-service's atomic reserve check. This constraint
-- solves a different problem: duplicate booking clicks from one user.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_active_booking_per_user_slot
  ON bookings (user_id, slot_id)
  WHERE status = 'confirmed';
