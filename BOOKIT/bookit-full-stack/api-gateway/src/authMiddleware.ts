import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { config } from './config';

export interface AuthenticatedRequest extends Request {
  user?: { sub: string; email: string; role: string };
}

/**
 * Reads the JWT from the httpOnly cookie (never from a header the browser
 * JS could have set) and verifies it. This is the ONLY place in the whole
 * system that should ever read the cookie directly - internal services
 * never see the cookie, only a verified identity forwarded as a header.
 */
export function requireAuth(req: AuthenticatedRequest, res: Response, next: NextFunction): void {
  const token = req.cookies?.[config.cookie.name];

  if (!token) {
    res.status(401).json({ error: 'Not authenticated' });
    return;
  }

  try {
    const payload = jwt.verify(token, config.jwtSecret) as { sub: string; email: string; role: string };
    req.user = payload;
    next();
  } catch {
    res.status(401).json({ error: 'Session expired or invalid' });
  }
}

/** Optional auth: attaches user if a valid cookie is present, but never blocks the request. */
export function attachUserIfPresent(req: AuthenticatedRequest, _res: Response, next: NextFunction): void {
  const token = req.cookies?.[config.cookie.name];
  if (token) {
    try {
      req.user = jwt.verify(token, config.jwtSecret) as { sub: string; email: string; role: string };
    } catch {
      // Invalid/expired cookie on an optional-auth route - just proceed unauthenticated.
    }
  }
  next();
}
