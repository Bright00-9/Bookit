export interface BookingEvent {
  type: 'booking.created' | 'booking.cancelled';
  bookingId: string;
  slotId: string;
  userId: string;
  userEmail: string;
  occurredAt: string;
}
