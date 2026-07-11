import { Router, Response } from 'express';
import { config } from './config';
import { proxyRequest } from './proxy';
import { requireAuth, attachUserIfPresent, AuthenticatedRequest } from './authMiddleware';

const router = Router();
const AVAILABILITY_URL = config.services.availability;

// Public: browsing slots doesn't require login.
router.get('/slots', attachUserIfPresent, (req: AuthenticatedRequest, res: Response) =>
  proxyRequest(req, res, AVAILABILITY_URL, '/slots'),
);

router.get('/slots/:id', attachUserIfPresent, (req: AuthenticatedRequest, res: Response) =>
  proxyRequest(req, res, AVAILABILITY_URL, `/slots/${req.params.id}`),
);

// Admin-only: creating slots requires auth. Role enforcement (admin-only)
// happens again inside availability-service itself - the gateway
// forwarding a role header is a convenience, not the sole security
// boundary. Defense in depth: never trust a single layer.
router.post('/slots', requireAuth, (req: AuthenticatedRequest, res: Response) =>
  proxyRequest(req, res, AVAILABILITY_URL, '/slots'),
);

export default router;
