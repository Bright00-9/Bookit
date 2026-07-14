-- Demo seed data so the board has something to look at and interact with
-- immediately after `docker compose up`, without manual setup first.
-- Safe to re-run: ON CONFLICT guards prevent duplicate inserts.

INSERT INTO users (email, password_hash, role)
VALUES ('admin@bookit.dev', '$2b$12$srLy0KBxmnlTBwMU.ZzX9uKUBeSABGfgxq.IP2cHIfa8lT/jiAmui', 'admin')
ON CONFLICT (email) DO NOTHING;
-- Demo admin login: admin@bookit.dev / admin12345
-- Change or remove this before ever deploying anywhere real.

INSERT INTO slots (title, start_time, end_time, capacity)
SELECT * FROM (
  VALUES
    ('Beginner Boxing', now() + interval '1 day', now() + interval '1 day 1 hour', 8),
    ('Advanced Sparring', now() + interval '2 days', now() + interval '2 days 1 hour', 4),
    ('Strength & Conditioning', now() + interval '3 days', now() + interval '3 days 1 hour', 12),
    ('1-on-1 Coaching', now() + interval '4 days', now() + interval '4 days 1 hour', 1)
) AS seed(title, start_time, end_time, capacity)
WHERE NOT EXISTS (
  SELECT 1 FROM slots WHERE slots.title = seed.title
);
