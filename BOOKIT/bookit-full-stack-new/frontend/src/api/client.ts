// Base URL comes from build-time env, never hardcoded - so the same build
// artifact can point at localhost in dev, staging, or prod just by
// changing an env var, no rebuild needed if you inject this at deploy
// time via a config endpoint (a common pattern once you're on K8s/AWS).
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8080';

export class ApiError extends Error {
  status: number;
  body: unknown;

  constructor(status: number, body: unknown) {
    super(`API error ${status}`);
    this.status = status;
    this.body = body;
  }
}

interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  body?: unknown;
}

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method ?? 'GET',
    headers: { 'Content-Type': 'application/json' },
    // This is the whole reason auth "just works" with zero token code in
    // the frontend: the browser automatically attaches the httpOnly
    // session cookie to same-origin-configured, credentialed requests.
    // The frontend never reads, stores, or sends a token manually.
    credentials: 'include',
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const data = await response.json().catch(() => undefined);

  if (!response.ok) {
    throw new ApiError(response.status, data);
  }

  return data as T;
}

export interface User {
  id: string;
  email: string;
  role: 'customer' | 'admin';
}

export interface Slot {
  id: string;
  title: string;
  startTime: string;
  endTime: string;
  capacity: number;
  bookedCount: number;
}

export interface Booking {
  id: string;
  slotId: string;
  status: 'confirmed' | 'cancelled';
  createdAt: string;
}

export const api = {
  signup: (email: string, password: string) =>
    request<{ user: User }>('/auth/signup', { method: 'POST', body: { email, password } }),

  login: (email: string, password: string) =>
    request<{ user: User }>('/auth/login', { method: 'POST', body: { email, password } }),

  logout: () => request<{ status: string }>('/auth/logout', { method: 'POST' }),

  me: () => request<{ user: User }>('/auth/me'),

  listSlots: () => request<{ slots: Slot[] }>('/slots'),

  createSlot: (input: { title: string; startTime: string; endTime: string; capacity: number }) =>
    request<{ slot: Slot }>('/slots', { method: 'POST', body: input }),

  createBooking: (slotId: string) =>
    request<{ booking: Booking }>('/bookings', { method: 'POST', body: { slotId } }),

  listBookings: () => request<{ bookings: Booking[] }>('/bookings'),

  cancelBooking: (bookingId: string) =>
    request<{ booking: Booking }>(`/bookings/${bookingId}/cancel`, { method: 'POST' }),
};
