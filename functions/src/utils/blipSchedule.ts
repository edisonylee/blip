export interface BlipSchedule {
  timezoneIdentifier: string;
  activeStartHour: number;
  activeEndHour: number;
}

export function scheduleFrom(data: Record<string, unknown>): BlipSchedule {
  return {
    timezoneIdentifier: typeof data.timezoneIdentifier === "string"
      ? data.timezoneIdentifier
      : "UTC",
    activeStartHour: validHour(data.activeStartHour) ? data.activeStartHour : 4,
    activeEndHour: validHour(data.activeEndHour) ? data.activeEndHour : 4,
  };
}

export function hourInTimezone(date: Date, timezoneIdentifier: string): number {
  const parts = localParts(date, timezoneIdentifier);
  return parts.hour;
}

export function dateKeyFor(
  date: Date,
  timezoneIdentifier: string,
  activeStartHour: number,
): string {
  const parts = localParts(date, timezoneIdentifier);
  const calendarDate = new Date(Date.UTC(parts.year, parts.month - 1, parts.day));
  if (parts.hour < activeStartHour) {
    calendarDate.setUTCDate(calendarDate.getUTCDate() - 1);
  }
  return [
    calendarDate.getUTCFullYear(),
    String(calendarDate.getUTCMonth() + 1).padStart(2, "0"),
    String(calendarDate.getUTCDate()).padStart(2, "0"),
  ].join("-");
}

export function isActiveHour(hour: number, startHour: number, endHour: number): boolean {
  if (startHour === endHour) return true;
  if (startHour < endHour) return hour >= startHour && hour < endHour;
  return hour >= startHour || hour < endHour;
}

export function orderedHours(startHour: number, endHour: number): number[] {
  const count = startHour === endHour ? 24 : (endHour - startHour + 24) % 24;
  return Array.from({ length: count }, (_, index) => (startHour + index) % 24);
}

function validHour(value: unknown): value is number {
  return Number.isInteger(value) && (value as number) >= 0 && (value as number) <= 23;
}

function localParts(date: Date, timezoneIdentifier: string): {
  year: number;
  month: number;
  day: number;
  hour: number;
} {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezoneIdentifier,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    hourCycle: "h23",
  });
  const values = new Map(
    formatter.formatToParts(date).map((part) => [part.type, part.value]),
  );
  return {
    year: Number(values.get("year")),
    month: Number(values.get("month")),
    day: Number(values.get("day")),
    hour: Number(values.get("hour")),
  };
}
