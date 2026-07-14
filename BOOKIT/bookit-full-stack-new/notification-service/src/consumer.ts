import amqp, { ChannelModel, Channel, ConsumeMessage } from 'amqplib';
import { config } from './config';
import { BookingEvent } from './events';
import { Notifier } from './notifier';
import { log, logError } from './logger';

let connection: ChannelModel | undefined;
let channel: Channel | undefined;

/**
 * Message queues like SQS/RabbitMQ guarantee "at-least-once" delivery, not
 * "exactly-once". If this process crashes after sending a notification but
 * before acking the message, the broker will redeliver it - meaning the
 * SAME booking.created event could be processed twice. Without a guard,
 * that means duplicate confirmation emails.
 *
 * This in-memory Set is a minimal idempotency guard for local dev: we
 * remember which (event type, bookingId) pairs we've already handled and
 * skip repeats. It resets on restart, which is fine for learning purposes
 * but NOT production-safe - a real deployment would track processed
 * message IDs in Redis or a DB table with a TTL, so the guard survives a
 * pod restart. Worth revisiting once you build the Redis/ElastiCache
 * piece of this project.
 */
const processedEvents = new Set<string>();

function eventKey(event: BookingEvent): string {
  return `${event.type}:${event.bookingId}`;
}

async function handleEvent(event: BookingEvent, notifier: Notifier): Promise<void> {
  const key = eventKey(event);
  if (processedEvents.has(key)) {
    log(`Skipping duplicate delivery of ${key}`);
    return;
  }

  await notifier.send(event);
  processedEvents.add(key);
}

export async function startConsumer(notifier: Notifier): Promise<void> {
  connection = await amqp.connect(config.rabbitUrl);
  connection.on('error', (err) => console.error('RabbitMQ connection error:', err));
  connection.on('close', () => console.warn('RabbitMQ connection closed'));

  channel = await connection.createChannel();
  await channel.assertQueue(config.bookingEventsQueue, { durable: true });

  // Process one message at a time before accepting the next. Without this,
  // a burst of events could all be pulled into memory and processed
  // concurrently, defeating the purpose of the idempotency guard's
  // ordering guarantees and making failures harder to reason about.
  await channel.prefetch(1);

  console.log(`Listening on queue "${config.bookingEventsQueue}"...`);

  await channel.consume(config.bookingEventsQueue, async (msg: ConsumeMessage | null) => {
    if (!msg) return;

    try {
      const event = JSON.parse(msg.content.toString()) as BookingEvent;
      log(`Received ${event.type} for booking ${event.bookingId}`);
      await handleEvent(event, notifier);
      channel!.ack(msg);
    } catch (err) {
      logError('Failed to process booking event', err);
      // requeue: false sends this to a dead-letter queue if one is
      // configured (not set up in this local dev version), rather than
      // looping forever on a message that will never succeed - e.g. one
      // with malformed JSON. Retrying forever on a "poison message" can
      // starve every other message behind it in the queue.
      channel!.nack(msg, false, false);
    }
  });
}

export async function closeConsumer(): Promise<void> {
  try {
    await channel?.close();
    await connection?.close();
  } catch (err) {
    console.error('Error closing RabbitMQ connection:', err);
  }
}
