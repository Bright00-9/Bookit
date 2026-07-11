import { BookingEvent } from './events';

export interface Notifier {
  send(event: BookingEvent): Promise<void>;
}

/**
 * Stand-in for a real provider. In production this would be swapped for
 * an SES (email) or SNS (SMS) implementation - the interface above is
 * exactly what makes that swap contained to one new file, with zero
 * changes to consumer.ts or how events are processed.
 */
export class ConsoleNotifier implements Notifier {
  async send(event: BookingEvent): Promise<void> {
    const message =
      event.type === 'booking.created'
        ? `Booking confirmed for slot ${event.slotId}`
        : `Booking cancelled for slot ${event.slotId}`;

    console.log(
      `[notification] -> ${event.userEmail}: ${message} (booking ${event.bookingId}, at ${event.occurredAt})`,
    );
  }
}
