import axios from 'axios';
import { config } from './config';

export interface Identity {
  userId: string;
  email: string;
  role: string;
}

function identityHeaders(identity: Identity): Record<string, string> {
  return {
    'x-user-id': identity.userId,
    'x-user-email': identity.email,
    'x-user-role': identity.role,
  };
}

export class SlotFullError extends Error {
  constructor() {
    super('Slot is full');
  }
}

export async function reserveSlot(slotId: string, identity: Identity): Promise<void> {
  try {
    await axios.post(
      `${config.availabilityServiceUrl}/slots/${slotId}/reserve`,
      {},
      { headers: identityHeaders(identity) },
    );
  } catch (err) {
    if (axios.isAxiosError(err) && err.response?.status === 409) {
      throw new SlotFullError();
    }
    throw err;
  }
}

export async function releaseSlot(slotId: string, identity: Identity): Promise<void> {
  // Best-effort on purpose: if this fails, the slot's booked_count could
  // stay incorrectly high until manually reconciled. In production, this
  // is another good candidate for the outbox/retry pattern mentioned in
  // messageBus.ts - log loudly for now so it's visible in monitoring
  // (this is exactly the kind of gap Prometheus alerting would catch).
  try {
    await axios.post(
      `${config.availabilityServiceUrl}/slots/${slotId}/release`,
      {},
      { headers: identityHeaders(identity) },
    );
  } catch (err) {
    console.error(`Failed to release slot ${slotId} in availability-service:`, err);
  }
}
