import { Router, Request, Response } from 'express';
import bcrypt from 'bcrypt';
import { signupSchema, loginSchema } from './schemas';
import { findUserByEmail, createUser } from './userRepository';
import { signToken, verifyToken } from './jwt';
import { log } from './logger';

const router = Router();
const SALT_ROUNDS = 12;

router.post('/signup', async (req: Request, res: Response) => {
  const parsed = signupSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { email, password } = parsed.data;

  const existing = await findUserByEmail(email);
  if (existing) {
    log(`Signup rejected — account already exists for ${email}`);
    // Deliberately generic message — don't reveal whether an email
    // exists in the system to unauthenticated callers.
    return res.status(409).json({ error: 'Unable to create account with these details' });
  }

  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
  const user = await createUser(email, passwordHash);
  log(`New account created: ${user.email} (${user.id})`);

  const token = signToken({ sub: user.id, email: user.email, role: user.role });
  return res.status(201).json({ token, user: { id: user.id, email: user.email, role: user.role } });
});

router.post('/login', async (req: Request, res: Response) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { email, password } = parsed.data;

  const user = await findUserByEmail(email);
  // Same generic error whether the email doesn't exist or the password is
  // wrong — prevents attackers from using this endpoint to enumerate
  // valid emails.
  const invalidCredentialsError = { error: 'Invalid email or password' };

  if (!user) {
    log(`Login failed — no account for ${email}`);
    return res.status(401).json(invalidCredentialsError);
  }

  const passwordMatches = await bcrypt.compare(password, user.passwordHash);
  if (!passwordMatches) {
    log(`Login failed — wrong password for ${email}`);
    return res.status(401).json(invalidCredentialsError);
  }

  log(`Login succeeded: ${user.email} (${user.role})`);
  const token = signToken({ sub: user.id, email: user.email, role: user.role });
  return res.status(200).json({ token, user: { id: user.id, email: user.email, role: user.role } });
});

// Used by other services (via the API gateway) to verify a token is valid
// and extract the user identity/role without duplicating JWT logic everywhere.
router.post('/verify', (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : undefined;

  if (!token) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }

  try {
    const payload = verifyToken(token);
    return res.status(200).json({ valid: true, payload });
  } catch {
    return res.status(401).json({ valid: false, error: 'Invalid or expired token' });
  }
});

export default router;
