import axios, { Method } from 'axios';
import { Response } from 'express';
import { AuthenticatedRequest } from './authMiddleware';

/**
 * Proxies a request to an internal service. Instead of forwarding the raw
 * JWT downstream, we forward the already-verified identity as plain
 * headers (x-user-id / x-user-email / x-user-role). Internal services
 * trust these headers because, in production, network policies ensure
 * only the gateway can reach them directly - end users and the public
 * internet cannot bypass the gateway to call them with forged headers.
 *
 * This also means internal services don't need to know about JWTs or the
 * cookie at all - one less thing duplicated across five services.
 */
export async function proxyRequest(
  req: AuthenticatedRequest,
  res: Response,
  targetBaseUrl: string,
  targetPath: string,
): Promise<void> {
  try {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (req.user) {
      headers['x-user-id'] = req.user.sub;
      headers['x-user-email'] = req.user.email;
      headers['x-user-role'] = req.user.role;
    }

    const response = await axios.request({
      method: req.method as Method,
      url: `${targetBaseUrl}${targetPath}`,
      data: req.body,
      params: req.query,
      headers,
      validateStatus: () => true, // let us forward the upstream status as-is
    });

    res.status(response.status).json(response.data);
  } catch (err) {
    console.error(`Proxy error forwarding to ${targetBaseUrl}${targetPath}:`, err);
    res.status(502).json({ error: 'Upstream service unavailable' });
  }
}
