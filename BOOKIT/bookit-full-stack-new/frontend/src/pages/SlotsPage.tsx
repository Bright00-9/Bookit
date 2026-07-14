import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, ApiError } from '../api/client';
import type { Slot, Booking } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { SeatGauge } from '../components/SeatGauge';

export function SlotsPage() {
  const { user, logout } = useAuth();
  const [slots, setSlots] = useState<Slot[]>([]);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionId, setActionId] = useState<string | null>(null);

  async function loadData() {
    try {
      const { slots } = await api.listSlots();
      setSlots(slots);
      if (user) {
        const { bookings } = await api.listBookings();
        setBookings(bookings.filter((b) => b.status === 'confirmed'));
      }
    } catch {
      setError('Could not load the board right now.');
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
    setActionId(slotId);
    try {
      await api.createBooking(slotId);
      await loadData();
    } catch (err) {
      setError(err instanceof ApiError ? extractError(err, 'Could not reserve this seat.') : 'Something went wrong.');
    } finally {
      setActionId(null);
    }
  }

  async function handleCancel(bookingId: string) {
    setError(null);
    setActionId(bookingId);
    try {
      await api.cancelBooking(bookingId);
      await loadData();
    } catch (err) {
      setError(err instanceof ApiError ? extractError(err, 'Could not cancel this booking.') : 'Something went wrong.');
    } finally {
      setActionId(null);
    }
  }

  if (loading) return <div className="loading-screen">LOADING BOARD…</div>;

  return (
    <>
      <div className="topbar">
        <span className="wordmark">
          <span className="dot" />
          BOOKIT
        </span>
        <div className="session-info">
          {user ? (
            <>
              <span>{user.email}</span>
              {user.role === 'admin' && <Link to="/admin/slots" style={{ color: 'var(--accent)' }}>Add session</Link>}
              <button onClick={() => logout()}>Log out</button>
            </>
          ) : (
            <Link to="/login" style={{ color: 'var(--accent)', fontSize: '0.85rem' }}>Log in</Link>
          )}
        </div>
      </div>

      <div className="page-shell">
        <div className="board-header">
          <h1>Upcoming sessions</h1>
          <span className="sub">{slots.length} scheduled</span>
        </div>

        <div className="board-columns">
          <span>Session</span>
          <span>Seats</span>
          <span>Status</span>
        </div>

        {error && <p className="error" style={{ marginBottom: '1rem' }}>{error}</p>}

        {slots.length === 0 ? (
          <div className="empty-state">No sessions on the board yet.</div>
        ) : (
          <ul className="slots-list">
            {slots.map((slot) => {
              const isFull = slot.bookedCount >= slot.capacity;
              const myBooking = bookingForSlot(slot.id);
              const busy = actionId === slot.id || actionId === myBooking?.id;

              return (
                <li key={slot.id} className={`slot-row${myBooking ? ' mine' : ''}${isFull && !myBooking ? ' full' : ''}`}>
                  <div className="slot-main">
                    <p className="title">{slot.title}</p>
                    <p className="time">
                      {new Date(slot.startTime).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
                      {' – '}
                      {new Date(slot.endTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </p>
                  </div>

                  <SeatGauge capacity={slot.capacity} bookedCount={slot.bookedCount} />

                  <div className="slot-action">
                    {myBooking && <span className="badge booked">Booked</span>}
                    {!myBooking && isFull && <span className="badge full">Full</span>}

                    {user && myBooking && (
                      <button className="secondary" disabled={busy} onClick={() => handleCancel(myBooking.id)}>
                        {busy ? 'Cancelling…' : 'Cancel'}
                      </button>
                    )}
                    {user && !myBooking && (
                      <button disabled={busy || isFull} onClick={() => handleBook(slot.id)}>
                        {busy ? 'Booking…' : isFull ? 'Full' : 'Reserve seat'}
                      </button>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}

        {!user && (
          <p className="guest-note">
            <Link to="/login">Log in</Link> or <Link to="/signup">sign up</Link> to reserve a seat.
          </p>
        )}
      </div>
    </>
  );
}

function extractError(err: ApiError, fallback: string): string {
  const body = err.body as { error?: string };
  return typeof body?.error === 'string' ? body.error : fallback;
}
