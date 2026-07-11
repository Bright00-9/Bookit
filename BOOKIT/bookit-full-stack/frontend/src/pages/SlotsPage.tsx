import { useEffect, useState } from 'react';
import { api, ApiError } from '../api/client';
import type { Slot, Booking } from '../api/client';
import { useAuth } from '../context/AuthContext';

export function SlotsPage() {
  const { user, logout } = useAuth();
  const [slots, setSlots] = useState<Slot[]>([]);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionSlotId, setActionSlotId] = useState<string | null>(null);

  async function loadData() {
    try {
      const { slots } = await api.listSlots();
      setSlots(slots);
      if (user) {
        const { bookings } = await api.listBookings();
        setBookings(bookings.filter((b) => b.status === 'confirmed'));
      }
    } catch {
      setError('Could not load slots');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  function bookingForSlot(slotId: string): Booking | undefined {
    return bookings.find((b) => b.slotId === slotId);
  }

  async function handleBook(slotId: string) {
    setError(null);
    setActionSlotId(slotId);
    try {
      await api.createBooking(slotId);
      await loadData();
    } catch (err) {
      if (err instanceof ApiError) {
        setError((err.body as { error?: string })?.error ?? 'Could not book this slot');
      } else {
        setError('Something went wrong.');
      }
    } finally {
      setActionSlotId(null);
    }
  }

  async function handleCancel(bookingId: string) {
    setError(null);
    setActionSlotId(bookingId);
    try {
      await api.cancelBooking(bookingId);
      await loadData();
    } catch (err) {
      if (err instanceof ApiError) {
        setError((err.body as { error?: string })?.error ?? 'Could not cancel this booking');
      } else {
        setError('Something went wrong.');
      }
    } finally {
      setActionSlotId(null);
    }
  }

  if (loading) return <div className="loading-screen">Loading slots...</div>;

  return (
    <div className="slots-page">
      <header>
        <h1>Upcoming Slots</h1>
        <div>
          {user ? (
            <>
              <span>{user.email}</span>
              <button onClick={() => logout()}>Log out</button>
            </>
          ) : (
            <span>Browsing as guest</span>
          )}
        </div>
      </header>

      {error && <p className="error">{error}</p>}

      <ul className="slots-list">
        {slots.map((slot) => {
          const isFull = slot.bookedCount >= slot.capacity;
          const myBooking = bookingForSlot(slot.id);
          const busy = actionSlotId === slot.id || actionSlotId === myBooking?.id;

          return (
            <li key={slot.id} className={isFull ? 'slot full' : 'slot'}>
              <h3>{slot.title}</h3>
              <p>
                {new Date(slot.startTime).toLocaleString()} –{' '}
                {new Date(slot.endTime).toLocaleTimeString()}
              </p>
              <p>
                {slot.bookedCount} / {slot.capacity} booked
                {isFull && !myBooking && ' — FULL'}
              </p>

              {!user && <p>Log in to book a slot.</p>}

              {user && myBooking && (
                <button disabled={busy} onClick={() => handleCancel(myBooking.id)}>
                  {busy ? 'Cancelling...' : 'Cancel booking'}
                </button>
              )}

              {user && !myBooking && (
                <button disabled={busy || isFull} onClick={() => handleBook(slot.id)}>
                  {busy ? 'Booking...' : isFull ? 'Full' : 'Book this slot'}
                </button>
              )}
            </li>
          );
        })}
        {slots.length === 0 && <p>No upcoming slots yet.</p>}
      </ul>
    </div>
  );
}
