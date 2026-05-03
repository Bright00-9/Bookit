-- Run in Supabase SQL Editor

-- Admin users table (separate from app users)
create table admin_users (
  id uuid default gen_random_uuid() primary key,
  email text unique not null,
  name text not null,
  password_hash text not null,
  created_at timestamp default now()
);

-- Add is_suspended column to profiles if not exists
alter table profiles add column if not exists is_suspended boolean default false;

-- Insert default admin (password: admin123 - CHANGE THIS!)
insert into admin_users (email, name, password_hash)
values (
  'admin@moka.com',
  'Moka Admin',
  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi' -- admin123
);
