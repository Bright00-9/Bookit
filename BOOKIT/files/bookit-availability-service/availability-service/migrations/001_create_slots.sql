CREATE TABLE IF NOT EXISTS slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  capacity INT NOT NULL CHECK (capacity > 0),
  booked_count INT NOT NULL DEFAULT 0 CHECK (booked_count >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Belt-and-suspenders: even if application logic has a bug, the DB
  -- itself will refuse to let booked_count exceed capacity.
  CONSTRAINT booked_count_within_capacity CHECK (booked_count <= capacity)
);

CREATE INDEX IF NOT EXISTS idx_slots_start_time ON slots (start_time);
