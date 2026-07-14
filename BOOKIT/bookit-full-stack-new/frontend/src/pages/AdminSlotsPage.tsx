import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { api, ApiError } from '../api/client';

export function AdminSlotsPage() {
  const [title, setTitle] = useState('');
  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');
  const [capacity, setCapacity] = useState(10);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setMessage(null);
    setError(null);
    try {
      await api.createSlot({
        title,
        startTime: new Date(startTime).toISOString(),
        endTime: new Date(endTime).toISOString(),
        capacity,
      });
      setMessage('Session added to the board.');
      setTitle('');
      setStartTime('');
      setEndTime('');
      setCapacity(10);
    } catch (err) {
      if (err instanceof ApiError) {
        setError((err.body as { error?: string })?.error ?? 'Could not create session');
      } else {
        setError('Something went wrong.');
      }
    }
  }

  return (
    <div className="admin-shell">
      <div className="ticket-card">
        <div className="ticket-body">
          <p className="eyebrow">Admin</p>
          <h1>Add a session</h1>
          <form onSubmit={handleSubmit}>
            <label>
              Title
              <input value={title} onChange={(e) => setTitle(e.target.value)} required />
            </label>
            <div className="field-row">
              <label>
                Starts
                <input
                  type="datetime-local"
                  value={startTime}
                  onChange={(e) => setStartTime(e.target.value)}
                  required
                />
              </label>
              <label>
                Ends
                <input
                  type="datetime-local"
                  value={endTime}
                  onChange={(e) => setEndTime(e.target.value)}
                  required
                />
              </label>
            </div>
            <label>
              Capacity
              <input
                type="number"
                min={1}
                value={capacity}
                onChange={(e) => setCapacity(Number(e.target.value))}
                required
              />
            </label>
            {message && <p className="success">{message}</p>}
            {error && <p className="error">{error}</p>}
            <button type="submit">Add to board</button>
          </form>
          <p>
            <Link to="/">Back to board</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
