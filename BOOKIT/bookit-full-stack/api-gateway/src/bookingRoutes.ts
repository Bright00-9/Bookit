import { Router, Response } from 'express';
import { config } from './config';
import { proxyRequest } from './proxy';
import { requireAuth, AuthenticatedRequest } from './authMiddleware';

const router = Router();
const BOOKING_URL = config.services.booking;

router.use(requireAuth);

router.post('/bookings', (req: AuthenticatedRequest, res: Response) =>
  proxyRequest(req, res, BOOKING_URL, '/bookings'),
);

router.get('/bookings', (req: AuthenticatedRequest, res: Response) =>
  proxyRequest(req, res, BOOKING_URL, '/bookings'),
);

router.post('/bookings/:id/cancel', (req: AuthenticatedRequest, res: Response) =>
  proxyRequest(req, res, BOOKING_URL, `/bookings/${req.params.id}/cancel`),
);

export default router;
