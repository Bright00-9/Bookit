interface SeatGaugeProps {
  capacity: number;
  bookedCount: number;
}

/**
 * Renders capacity as a row of ticks, filling in left-to-right as seats
 * are booked - like a split-flap departures board updating. Capped at 20
 * visible ticks so a capacity of e.g. 200 doesn't render 200 divs; above
 * that we fall back to compressed dots representing groups of seats.
 */
export function SeatGauge({ capacity, bookedCount }: SeatGaugeProps) {
  const isFull = bookedCount >= capacity;
  const maxTicks = 20;
  const showCompressed = capacity > maxTicks;

  const tickCount = showCompressed ? maxTicks : capacity;
  const filledTicks = showCompressed
    ? Math.round((bookedCount / capacity) * maxTicks)
    : bookedCount;

  return (
    <div className={`seat-gauge${isFull ? ' full' : ''}`}>
      <div className="ticks">
        {Array.from({ length: tickCount }).map((_, i) => (
          <div key={i} className={`tick${i < filledTicks ? ' filled' : ''}`} />
        ))}
      </div>
      <span className="label">
        {bookedCount}/{capacity} seats
      </span>
    </div>
  );
}
