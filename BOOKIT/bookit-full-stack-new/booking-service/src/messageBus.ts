import amqp, { Channel, ChannelModel } from 'amqplib';
import { config } from './config';

let connection: ChannelModel | undefined;
let channel: Channel | undefined;

/**
 * Lazily connects on first publish, and reconnects on the next publish
 * attempt if the connection was lost. We deliberately don't crash the
 * service if RabbitMQ is unreachable - a booking is still valid even if
 * the "send a confirmation email" event can't be published right this
 * second. This is the same reasoning behind SQS in production: decouple
 * the critical path (the booking itself) from the side effect (notifying
 * someone), so a notification outage never takes down bookings.
 */
async function getChannel(): Promise<Channel> {
  if (channel) return channel;

  connection = await amqp.connect(config.rabbitUrl);
  connection.on('error', (err) => {
    console.error('RabbitMQ connection error:', err);
    channel = undefined;
  });
  connection.on('close', () => {
    console.warn('RabbitMQ connection closed');
    channel = undefined;
  });

  channel = await connection.createChannel();
  await channel.assertQueue(config.bookingEventsQueue, { durable: true });
  return channel;
}

export interface BookingEvent {
  type: 'booking.created' | 'booking.cancelled';
  bookingId: string;
  slotId: string;
  userId: string;
  userEmail: string;
  occurredAt: string;
}

export async function publishBookingEvent(event: BookingEvent): Promise<void> {
  try {
    const ch = await getChannel();
    ch.sendToQueue(config.bookingEventsQueue, Buffer.from(JSON.stringify(event)), {
      persistent: true, // survives a broker restart, so we don't silently lose a queued notification
    });
  } catch (err) {
    // Deliberately swallowed: publishing failure should never fail the
    // HTTP request that already committed a real booking/cancellation.
    // In a production system, this is exactly where you'd add an
    // "outbox" table - write the event to Postgres in the same
    // transaction as the booking, then a background worker retries
    // publishing until it succeeds. That guarantees zero lost events
    // even across a full RabbitMQ outage, at the cost of the extra
    // moving part. Worth building once this project reaches EKS.
    console.error('Failed to publish booking event (will not block the request):', err);
  }
}

export async function closeMessageBus(): Promise<void> {
  try {
    await channel?.close();
    await connection?.close();
  } catch (err) {
    console.error('Error closing RabbitMQ connection:', err);
  }
}
