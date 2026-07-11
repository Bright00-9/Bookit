import axios from 'axios';
import { Router, Request, Response } from 'express';
import { config } from './config';
import { requireAuth, AuthenticatedRequest } from './authMiddleware';

const router = Router();

const cookieOptions = {
  httpOnly: true, // JavaScript can never read this cookie - blocks XSS token theft
  secure: config.nodeEnv === 'production', // HTTPS-only in production
  sameSite: 'lax' as const, // CSRF mitigation while still allowing normal navigation
  maxAge: config.cookie.maxAgeMs,
};

router.post('/auth/signup', async (req: Request, res: Response) => {
  try {
    const response = await axios.post(`${config.services.auth}/auth/signup`, req.body);
    const { token, user } = response.data;
    res.cookie(config.cookie.name, token, cookieOptions);
    // Token itself is never sent to the client in the response body -
    // only the cookie carries it, and only the non-sensitive user profile
    // goes back in JSON.
    res.status(201).json({ user });
  } catch (err) {
    forwardError(err, res);
  }
});

router.post('/auth/login', async (req: Request, res: Response) => {
  try {
    const response = await axios.post(`${config.services.auth}/auth/login`, req.body);
    const { token, user } = response.data;
    res.cookie(config.cookie.name, token, cookieOptions);
    res.status(200).json({ user });
  } catch (err) {
    forwardError(err, res);
  }
});

router.post('/auth/logout', (_req: Request, res: Response) => {
  res.clearCookie(config.cookie.name, cookieOptions);
  res.status(200).json({ status: 'logged out' });
});

// Lets the frontend ask "am I logged in, and as whom" without ever
// touching the JWT itself - the gateway already verified it via requireAuth.
router.get('/auth/me', requireAuth, (req: AuthenticatedRequest, res: Response) => {
  res.status(200).json({ user: req.user });
});

function forwardError(err: unknown, res: Response): void {
  if (axios.isAxiosError(err) && err.response) {
    res.status(err.response.status).json(err.response.data);
    return;
  }
  console.error('Upstream request failed:', err);
  res.status(502).json({ error: 'Upstream service unavailable' });
}

export default router;
