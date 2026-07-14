import { NextFunction, Request, Response } from 'express';

export interface AuthenticatedRequest extends Request {
  user?: { sub: string; email: string; role: string };
}

/**
 * IMPORTANT: this service is never reached directly by end users - only by
 * the api-gateway, which already verified the JWT and forwards identity as
 * plain headers (x-user-id / x-user-email / x-user-role). This is why we
 * trust headers here instead of re-verifying a token: this service doesn't
 * even have the JWT secret.
 *
 * This trust boundary is only safe because, in production, network
 * policies (e.g. Kubernetes NetworkPolicy) prevent anything except the
 * gateway from reaching this service's pods directly. Locally, treat this
 * as a reminder to add that network policy before going anywhere near
 * real user data.
 */
export function requireAuth(req: AuthenticatedRequest, res: Response, next: NextFunction): void {
  const userId = req.header('x-user-id');
  const email = req.header('x-user-email');
  const role = req.header('x-user-role');

  if (!userId || !email || !role) {
    res.status(401).json({ error: 'Missing forwarded identity from gateway' });
    return;
  }

  req.user = { sub: userId, email, role };
  next();
}

export function requireRole(role: string) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
    if (req.user?.role !== role) {
      res.status(403).json({ error: 'Insufficient permissions' });
      return;
    }
    next();
  };
}
