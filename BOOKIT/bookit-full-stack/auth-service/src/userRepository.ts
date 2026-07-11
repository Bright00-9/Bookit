import { pool } from './db';

export interface User {
  id: string;
  email: string;
  passwordHash: string;
  role: 'customer' | 'admin';
  createdAt: string;
}

// Maps a raw DB row (snake_case) to our internal camelCase User type.
// Keeping this mapping in one place means the rest of the app never
// touches raw column names directly.
function mapRow(row: any): User {
  return {
    id: row.id,
    email: row.email,
    passwordHash: row.password_hash,
    role: row.role,
    createdAt: row.created_at,
  };
}

export async function findUserByEmail(email: string): Promise<User | null> {
  const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  if (result.rowCount === 0) return null;
  return mapRow(result.rows[0]);
}

export async function createUser(email: string, passwordHash: string): Promise<User> {
  const result = await pool.query(
    `INSERT INTO users (email, password_hash)
     VALUES ($1, $2)
     RETURNING *`,
    [email, passwordHash],
  );
  return mapRow(result.rows[0]);
}
